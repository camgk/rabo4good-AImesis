#!/usr/bin/env bash
# Tear down everything Terraform created (Cloud Run, Firestore data stays: the (default) database is abandoned, not deleted
# incl. its data, registry + images, service accounts, IAM grants).
# Leaves the state/build buckets and enabled APIs in place.
# Usage: infra/scripts/destroy.sh [--yes]
set -euo pipefail

# shellcheck source=infra/scripts/_common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    -y | --yes) ASSUME_YES=1 ;;
    -h | --help)
      sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "Unknown argument: $arg" ;;
  esac
done

resolve_config

printf '\n%sThis destroys the AImesis demo in project %s:%s\n' "$C_BOLD" "$PROJECT_ID" "$C_RESET"
info "Cloud Run services, the Firestore database is kept (deletion_policy ABANDON), Artifact Registry 'aimesis' (all images),"
info "service accounts and IAM grants. Buckets gs://${STATE_BUCKET} and gs://${BUILD_BUCKET} are kept."
if [ "$ASSUME_YES" != "1" ]; then
  printf '\nType the project id to confirm: '
  read -r answer
  [ "$answer" = "$PROJECT_ID" ] || die "Confirmation did not match; nothing destroyed."
fi

bash "$SCRIPT_DIR/bootstrap.sh"
setup_auth

step "terraform destroy"
tf destroy -auto-approve -input=false \
  -var-file=env/dev.tfvars \
  -var "project_id=${PROJECT_ID}" \
  -var "region=${REGION}" \
  -var "image_tag=destroy"
ok "Destroyed."
info "To remove the buckets too:"
info "  gcloud storage rm -r gs://${STATE_BUCKET} gs://${BUILD_BUCKET}"
