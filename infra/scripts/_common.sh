#!/usr/bin/env bash
# Shared helpers for infra/scripts/*.sh. Sourced, not executed.
# Must stay compatible with macOS /bin/bash 3.2 and BSD userland:
# no associative arrays, no mapfile, no ${var,,}, no GNU-only flags.

# --- paths -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TF_DIR="$REPO_ROOT/infra/terraform"
TFVARS="$TF_DIR/env/dev.tfvars"
# Auto-loaded by Terraform, git-ignored: remembers org-policy fallbacks.
LOCAL_TFVARS="$TF_DIR/local.auto.tfvars"

# --- output ------------------------------------------------------------------
if [ -t 1 ]; then
  C_BOLD=$'\033[1m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_RESET=$'\033[0m'
else
  C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_RESET=""
fi

step() { printf '\n%s==> %s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '    %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%sERROR:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found on PATH. $2"; }

# --- config ------------------------------------------------------------------
# tfvars_get <key>: read a simple string value  key = "value"  from dev.tfvars.
tfvars_get() {
  [ -f "$TFVARS" ] || return 0
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$TFVARS" | head -n 1
}

resolve_config() {
  need gcloud "Install the Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
  need terraform "Install Terraform >= 1.6 (brew install hashicorp/tap/terraform)."

  PROJECT_ID="${PROJECT_ID:-$(tfvars_get project_id)}"
  if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
  fi
  [ -n "$PROJECT_ID" ] || die "PROJECT_ID not set (env, env/dev.tfvars or 'gcloud config set project')."

  REGION="${REGION:-$(tfvars_get region)}"
  REGION="${REGION:-europe-west1}"
  STATE_BUCKET="${STATE_BUCKET:-${PROJECT_ID}-tfstate}"
  BUILD_BUCKET="${BUILD_BUCKET:-${PROJECT_ID}-build-src}"
  REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/aimesis"
  export PROJECT_ID REGION STATE_BUCKET BUILD_BUCKET REGISTRY
}

# Terraform authenticates with the same account gcloud uses (no separate
# `gcloud auth application-default login` needed). Set USE_ADC=1 to use ADC.
setup_auth() {
  local account
  account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n 1)"
  [ -n "$account" ] || die "gcloud is not logged in. Run: gcloud auth login"
  info "gcloud account: $account"
  if [ "${USE_ADC:-0}" != "1" ]; then
    GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)" \
      || die "Could not get an access token from gcloud."
    export GOOGLE_OAUTH_ACCESS_TOKEN
  fi
}

# --- terraform ---------------------------------------------------------------
tf() { terraform -chdir="$TF_DIR" "$@"; }

# tf_output <name>: raw output value, or empty if the state has no such output.
# (On an empty state terraform prints a warning to stdout, so filter it out.)
tf_output() {
  local v
  v="$(tf output -no-color -raw "$1" 2>/dev/null)" || return 0
  case "$v" in
    *"No outputs found"* | *Warning* | *$'\n'*) return 0 ;;
  esac
  printf '%s' "$v"
}

# local_flag <var> : print the value of a bool stored in local.auto.tfvars
local_flag() {
  [ -f "$LOCAL_TFVARS" ] || return 0
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\([a-z]*\).*/\1/p" "$LOCAL_TFVARS" | head -n 1
}

# set_local_flag <var> <true|false> : rewrite local.auto.tfvars with the flag set
set_local_flag() {
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/aimesis-tfvars.XXXXXX")"
  {
    echo "# Written by infra/scripts (org-policy fallbacks). Git-ignored. Delete to reset."
    if [ -f "$LOCAL_TFVARS" ]; then
      grep -v -e "^[[:space:]]*$1[[:space:]]*=" -e '^#' "$LOCAL_TFVARS" || true
    fi
    echo "$1 = $2"
  } >"$tmp"
  mv "$tmp" "$LOCAL_TFVARS"
}

# tf_apply_resilient <log-file> <terraform apply args...>
# Runs `terraform apply`; on two known org-policy failures it flips the
# matching fallback variable (persisted in local.auto.tfvars) and retries.
tf_apply_resilient() {
  local log="$1"; shift
  local attempt=1
  while [ "$attempt" -le 3 ]; do
    if tf apply -auto-approve -input=false "$@" 2>&1 | tee "$log"; then
      return 0
    fi
    if grep -q 'cloudbuild.gserviceaccount.com' "$log" \
      && grep -qiE 'does not exist|not found|invalid' "$log" \
      && [ "$(local_flag grant_legacy_cloudbuild_sa)" != "false" ]; then
      warn "Legacy Cloud Build SA not present; retrying with grant_legacy_cloudbuild_sa=false"
      set_local_flag grant_legacy_cloudbuild_sa false
    elif grep -q 'compute@developer.gserviceaccount.com' "$log" \
      && grep -qi 'does not exist' "$log"; then
      warn "Compute default SA not created yet (fresh project); waiting 30 s and retrying"
      sleep 30
    elif grep -qiE 'permitted customer|allowedPolicyMemberDomains|domain restricted' "$log" \
      && [ "$(local_flag public_via_invoker_iam_disabled)" != "true" ]; then
      warn "Org policy blocks allUsers; retrying with public_via_invoker_iam_disabled=true"
      set_local_flag public_via_invoker_iam_disabled true
    else
      return 1
    fi
    attempt=$((attempt + 1))
  done
  return 1
}
