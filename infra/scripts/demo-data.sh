#!/usr/bin/env bash
# Load / clear the AImesis demo dataset in the shared Firestore "(default)" database.
#
#   infra/scripts/demo-data.sh load [--reset]   upsert demo patients/accounts/resources (--reset: clear first)
#   infra/scripts/demo-data.sh clear [--yes]    dry run by default; --yes deletes demo-tagged docs only
#
# Env: PYTHON (python with google-cloud-firestore), PROJECT_ID / GOOGLE_CLOUD_PROJECT (default: dev.tfvars),
#      FIRESTORE_DATABASE (default "(default)"). Auth: Application Default Credentials
#      (gcloud auth application-default login).
# macOS bash 3.2 compatible.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=infra/scripts/_common.sh
. "$SCRIPT_DIR/_common.sh"

MOCK_DIR="$REPO_ROOT/backend/mock_api"

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

[ $# -ge 1 ] || usage 1
CMD="$1"; shift
case "$CMD" in
  load)  SCRIPT="$MOCK_DIR/scripts/load_demo_data.py" ;;
  clear) SCRIPT="$MOCK_DIR/scripts/clear_demo_data.py" ;;
  -h|--help|help) usage 0 ;;
  *) warn "Unknown command: $CMD"; usage 1 ;;
esac

# --- python with google-cloud-firestore --------------------------------------
has_firestore() { "$1" -c 'import google.cloud.firestore' >/dev/null 2>&1; }
PY=""
for cand in "${PYTHON:-}" "$HOME/development/mockvenv/bin/python3" python3; do
  [ -n "$cand" ] || continue
  if command -v "$cand" >/dev/null 2>&1 && has_firestore "$cand"; then PY="$cand"; break; fi
done
[ -n "$PY" ] || die "No python with google-cloud-firestore found. Set PYTHON=... or: python3 -m pip install google-cloud-firestore pydantic"
"$PY" -c 'import pydantic' >/dev/null 2>&1 || die "$PY lacks pydantic. Run: $PY -m pip install pydantic"

# --- project / database -------------------------------------------------------
PROJECT="${PROJECT_ID:-${GOOGLE_CLOUD_PROJECT:-$(tfvars_get project_id)}}"
[ -n "$PROJECT" ] || PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
[ -n "$PROJECT" ] || die "Project not set (PROJECT_ID env, infra/terraform/env/dev.tfvars or gcloud config)."
DATABASE="${FIRESTORE_DATABASE:-(default)}"

step "demo-data $CMD  (project $PROJECT, database $DATABASE)"
info "python: $PY"
exec "$PY" "$SCRIPT" --project "$PROJECT" --database "$DATABASE" "$@"
