#!/usr/bin/env bash
# Prepare a fresh GCP project for Terraform: enable the base APIs, create the
# state + build-source buckets, and `terraform init` against the GCS backend.
# Idempotent: safe to re-run. Usage: infra/scripts/bootstrap.sh
set -euo pipefail

# shellcheck source=infra/scripts/_common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

resolve_config
step "Bootstrap project ${PROJECT_ID} (${REGION})"
setup_auth

step "Enabling base APIs (can take a minute on a fresh project)"
gcloud services enable \
  serviceusage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  firestore.googleapis.com \
  iam.googleapis.com \
  compute.googleapis.com \
  --project "$PROJECT_ID"
ok "APIs enabled"

ensure_bucket() {
  local bucket="$1"
  if gcloud storage buckets describe "gs://${bucket}" --project "$PROJECT_ID" >/dev/null 2>&1; then
    ok "gs://${bucket} exists"
  else
    info "creating gs://${bucket}"
    gcloud storage buckets create "gs://${bucket}" \
      --project "$PROJECT_ID" \
      --location "$REGION" \
      --uniform-bucket-level-access \
      --public-access-prevention
    ok "gs://${bucket} created"
  fi
}

step "Terraform state bucket"
ensure_bucket "$STATE_BUCKET"
gcloud storage buckets update "gs://${STATE_BUCKET}" --versioning >/dev/null
ok "versioning on"

step "Cloud Build source bucket (EU, avoids the default US bucket)"
ensure_bucket "$BUILD_BUCKET"

step "terraform init"
tf init -reconfigure -input=false -backend-config="bucket=${STATE_BUCKET}"
ok "Terraform ready (state: gs://${STATE_BUCKET}/terraform/aimesis)"
