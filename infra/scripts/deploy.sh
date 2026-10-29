#!/usr/bin/env bash
# One-command deploy of the AImesis demo to Cloud Run.
#
#   infra/scripts/deploy.sh                    build all images + apply
#   infra/scripts/deploy.sh --only web         rebuild one image (api|web|family), keep the others
#   TAG=<tag> infra/scripts/deploy.sh --skip-build   re-apply with existing images
#                                                    (TAG defaults to the currently deployed tag)
#
# Env: PROJECT_ID, REGION (default from env/dev.tfvars), FLUTTER (path to flutter),
#      USE_ADC=1 (use application-default credentials instead of gcloud's token).
# Works on macOS /bin/bash 3.2 and Linux. Images are built remotely with Cloud Build
# (no local Docker needed).
set -euo pipefail

# shellcheck source=infra/scripts/_common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; }

SKIP_BUILD=0
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --only)
      [ $# -ge 2 ] || die "--only needs a value: api|web|family"
      ONLY="$2"
      shift
      ;;
    --only=*) ONLY="${1#--only=}" ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
  shift
done
case "$ONLY" in
  "" | web | family) ;;
  api | mock-api | mock_api) ONLY="api" ;;
  *) die "--only must be one of: api, web, family" ;;
esac

wants() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

T0=$(date +%s)
LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aimesis-deploy.XXXXXX")"
trap 'rm -rf "$LOG_DIR"' EXIT

# ---------------------------------------------------------------------------
# 1. Bootstrap (APIs, state bucket, terraform init)
# ---------------------------------------------------------------------------
bash "$SCRIPT_DIR/bootstrap.sh"
resolve_config
setup_auth

TF_COMMON_VARS="-var-file=env/dev.tfvars -var project_id=${PROJECT_ID} -var region=${REGION}"

# ---------------------------------------------------------------------------
# Resolve the tag and which images to (re)use
# ---------------------------------------------------------------------------
PREV_TAG="$(tf_output image_tag)"
PREV_MOCK_API_IMAGE="$(tf_output mock_api_image)"
PREV_WEB_IMAGE="$(tf_output web_image)"
PREV_FAMILY_WEB_IMAGE="$(tf_output family_web_image)"

if [ "$SKIP_BUILD" = "1" ]; then
  TAG="${TAG:-$PREV_TAG}"
  [ -n "$TAG" ] || die "--skip-build needs TAG=<tag> (no previous deploy found in state)."
else
  GIT_SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo nogit)"
  TAG="${GIT_SHA}-$(date -u +%Y%m%d-%H%M%S)"
fi
export TAG

# Image overrides: with --only, services that are not rebuilt keep their current image.
EXTRA_VARS=""
if [ -n "$ONLY" ]; then
  [ -n "$PREV_MOCK_API_IMAGE" ] || die "No previous deploy in state: run a full deploy (without --only) first."
  wants api || EXTRA_VARS="$EXTRA_VARS -var mock_api_image=${PREV_MOCK_API_IMAGE}"
  wants web || EXTRA_VARS="$EXTRA_VARS -var web_image=${PREV_WEB_IMAGE}"
  wants family || EXTRA_VARS="$EXTRA_VARS -var family_web_image=${PREV_FAMILY_WEB_IMAGE}"
fi

info "project:  $PROJECT_ID"
info "region:   $REGION"
info "registry: $REGISTRY"
info "tag:      $TAG${ONLY:+ (only: $ONLY)}"
if [ "$SKIP_BUILD" = "1" ]; then info "build:    skipped (reusing images)"; fi

# ---------------------------------------------------------------------------
# 2. Phase 1: foundations so images can be pushed
# ---------------------------------------------------------------------------
step "Terraform phase 1: APIs, Artifact Registry, Firestore, service accounts, IAM"
# shellcheck disable=SC2086 # word splitting of the var lists is intended
tf_apply_resilient "$LOG_DIR/phase1.log" $TF_COMMON_VARS -var "image_tag=${TAG}" \
  -target=google_project_service.apis \
  -target=google_artifact_registry_repository.aimesis \
  -target=google_firestore_database.default \
  -target=google_service_account.mock_api \
  -target=google_service_account.web \
  -target=google_project_iam_member.mock_api \
  -target=google_project_iam_member.build \
  -target=google_project_iam_member.team \
  -target=random_password.token_secret \
  || die "Phase 1 apply failed (see output above)."
ok "Foundations in place"

# ---------------------------------------------------------------------------
# 3. Build images with Cloud Build
# ---------------------------------------------------------------------------
resolve_flutter() {
  if [ -n "${FLUTTER:-}" ]; then
    command -v "$FLUTTER" >/dev/null 2>&1 || [ -x "$FLUTTER" ] || die "FLUTTER=$FLUTTER is not executable."
    return 0
  fi
  local candidate
  for candidate in "$(command -v flutter 2>/dev/null || true)" \
    "$HOME/development/flutter/bin/flutter" \
    "/opt/flutter/bin/flutter"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      FLUTTER="$candidate"
      return 0
    fi
  done
  die "flutter not found. Install it or set FLUTTER=/path/to/flutter."
}

# cloud_build <context-dir> <image> : remote docker build + push, one retry
# (fresh IAM grants for the Cloud Build SA can take a minute to propagate).
cloud_build() {
  local ctx="$1" image="$2" attempt
  for attempt in 1 2 3; do
    if gcloud builds submit "$ctx" \
      --project "$PROJECT_ID" \
      --tag "$image" \
      --gcs-source-staging-dir "gs://${BUILD_BUCKET}/source" \
      --quiet; then
      ok "pushed $image"
      return 0
    fi
    [ "$attempt" -lt 3 ] || break
    warn "Cloud Build failed (attempt $attempt); waiting 30 s for IAM propagation and retrying"
    sleep 30
  done
  die "Cloud Build failed for $image"
}

# web_context <flutter-app-dir> : temp build context = build/web + the web
# app's nginx Dockerfile and docker/ folder. Built in a temp dir because the
# apps' .gitignore excludes /build/, which gcloud would otherwise skip.
web_context() {
  local app_dir="$1" ctx web_dir="$REPO_ROOT/frontend/web" f
  [ -f "$app_dir/build/web/index.html" ] || die "No Flutter web build in $app_dir/build/web"
  ctx="$(mktemp -d "${TMPDIR:-/tmp}/aimesis-ctx.XXXXXX")"
  mkdir -p "$ctx/build"
  cp -R "$app_dir/build/web" "$ctx/build/web"
  cp "$web_dir/Dockerfile" "$ctx/Dockerfile"
  [ -d "$web_dir/docker" ] && cp -R "$web_dir/docker" "$ctx/docker"
  for f in .dockerignore nginx.conf default.conf entrypoint.sh docker-entrypoint.sh; do
    [ -f "$web_dir/$f" ] && cp "$web_dir/$f" "$ctx/$f"
  done
  printf '.gcloudignore\n' >"$ctx/.gcloudignore"
  echo "$ctx"
}

# mock_api_context : temp build context with backend/rules (aimesis_rules, the
# real engine) next to backend/mock_api; mock_api/Dockerfile goes at the root.
# (backend/ itself has another service's Dockerfile, so it can't be the context.)
mock_api_context() {
  local ctx
  ctx="$(mktemp -d "${TMPDIR:-/tmp}/aimesis-mockapi.XXXXXX")"
  rsync -a --exclude '.venv' --exclude '__pycache__' --exclude 'build' --exclude '*.egg-info' \
    --exclude '.pytest_cache' --exclude '.fuse_hidden*' "$REPO_ROOT/backend/rules" "$REPO_ROOT/backend/mock_api" "$ctx/"
  cp "$REPO_ROOT/backend/mock_api/Dockerfile" "$ctx/Dockerfile"
  printf '.gcloudignore\n' >"$ctx/.gcloudignore"
  echo "$ctx"
}

flutter_build() {
  local app_dir="$1"
  shift
  info "flutter build web in ${app_dir#"$REPO_ROOT"/}"
  (cd "$app_dir" && "$FLUTTER" build web --release "$@")
}

if [ "$SKIP_BUILD" != "1" ]; then
  step "Building images (tag $TAG)"

  if wants api; then
    [ -f "$REPO_ROOT/backend/mock_api/Dockerfile" ] || die "backend/mock_api/Dockerfile missing."
    info "mock-api: Cloud Build from temp context (backend/mock_api + backend/rules)"
    CTX="$(mock_api_context)"
    cloud_build "$CTX" "$REGISTRY/mock-api:$TAG"
  fi

  if wants web || wants family; then
    [ -s "$REPO_ROOT/frontend/web/Dockerfile" ] || die "frontend/web/Dockerfile is missing or empty (nginx image contract)."
    resolve_flutter
    info "flutter: $FLUTTER"
    (cd "$REPO_ROOT/frontend" && "$FLUTTER" pub get) || die "flutter pub get failed in frontend/"
  fi

  if wants web; then
    flutter_build "$REPO_ROOT/frontend/web"
    CTX="$(web_context "$REPO_ROOT/frontend/web")"
    cloud_build "$CTX" "$REGISTRY/web:$TAG"
    rm -rf "$CTX"
  fi

  if wants family; then
    # API URL comes from /config.json written by nginx at container start.
    flutter_build "$REPO_ROOT/frontend/ios" --dart-define=API_URL=
    CTX="$(web_context "$REPO_ROOT/frontend/ios")"
    cloud_build "$CTX" "$REGISTRY/family-web:$TAG"
    rm -rf "$CTX"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Phase 2: everything (Cloud Run services, public access)
# ---------------------------------------------------------------------------
step "Terraform phase 2: Cloud Run services"
setup_auth # refresh the access token after the (possibly long) builds
# shellcheck disable=SC2086
tf_apply_resilient "$LOG_DIR/phase2.log" $TF_COMMON_VARS -var "image_tag=${TAG}" $EXTRA_VARS \
  || die "Phase 2 apply failed (see output above)."

# ---------------------------------------------------------------------------
# 5. URLs + smoke test
# ---------------------------------------------------------------------------
MOCK_API_URL="$(tf_output mock_api_url)"
WEB_URL="$(tf_output web_url)"
FAMILY_WEB_URL="$(tf_output family_web_url)"

step "Smoke test"
smoke() {
  local url="$1" _
  for _ in 1 2 3 4 5 6; do
    if curl -fsS --max-time 10 "$url"; then
      echo
      return 0
    fi
    sleep 5
  done
  # Public access may be blocked by org policy: try with an identity token.
  curl -fsS --max-time 10 -H "Authorization: Bearer $(gcloud auth print-identity-token 2>/dev/null)" "$url" \
    && { echo; warn "$url only answers with an identity token: it is NOT public (see infra/README.md)."; return 0; }
  return 1
}
SMOKE_OK=1
check() {
  local label="$1" url="$2"
  if smoke "$url"; then
    ok "$label"
  else
    warn "$label failed ($url)"
    SMOKE_OK=0
  fi
}
check "mock-api /health" "$MOCK_API_URL/health"
check "web /config.json" "$WEB_URL/config.json"
check "family-web /config.json" "$FAMILY_WEB_URL/config.json"

step "Done in $(($(date +%s) - T0)) s (tag $TAG)"
printf '    %-12s %s\n' "web" "$WEB_URL" "family-web" "$FAMILY_WEB_URL" "mock-api" "$MOCK_API_URL"
info "Demo data: infra/scripts/demo-data.sh load [--reset]   |   infra/scripts/demo-data.sh clear [--yes]"
[ "$SMOKE_OK" = "1" ] || die "Deployed, but smoke tests failed. Check: gcloud run services logs read mock-api --region $REGION --project $PROJECT_ID"
