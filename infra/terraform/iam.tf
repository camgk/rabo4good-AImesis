# ---------------------------------------------------------------------------
# Runtime service accounts
# ---------------------------------------------------------------------------

resource "google_service_account" "mock_api" {
  project      = var.project_id
  account_id   = "aimesis-mock-api"
  display_name = "AImesis mock-api (Cloud Run)"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "mock_api" {
  for_each = toset([
    "roles/datastore.user",
    "roles/logging.logWriter",
    "roles/aiplatform.user", # Gemini on Vertex AI for the cycle summary
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.mock_api.email}"
}

# Static nginx frontends: no project roles at all.
resource "google_service_account" "web" {
  project      = var.project_id
  account_id   = "aimesis-web"
  display_name = "AImesis web frontends (Cloud Run, no roles)"

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# Build service accounts, so `gcloud builds submit` works in a fresh project.
# New projects run Cloud Build as the compute default SA; older ones use the
# legacy <number>@cloudbuild.gserviceaccount.com SA (exists once the Cloud
# Build API is enabled).
# ---------------------------------------------------------------------------

locals {
  build_roles = [
    "roles/cloudbuild.builds.builder", # recommended when builds run as the compute SA
    "roles/artifactregistry.writer",
    "roles/logging.logWriter",
    "roles/storage.objectViewer",
  ]

  build_service_accounts = merge(
    { compute = "${data.google_project.this.number}-compute@developer.gserviceaccount.com" },
    var.grant_legacy_cloudbuild_sa ? { cloudbuild = "${data.google_project.this.number}@cloudbuild.gserviceaccount.com" } : {},
  )

  build_bindings = {
    for pair in setproduct(keys(local.build_service_accounts), local.build_roles) :
    "${pair[0]}|${pair[1]}" => {
      member = "serviceAccount:${local.build_service_accounts[pair[0]]}"
      role   = pair[1]
    }
  }
}

resource "google_project_iam_member" "build" {
  for_each = local.build_bindings

  project = var.project_id
  role    = each.value.role
  member  = each.value.member

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# Teammates
# ---------------------------------------------------------------------------

locals {
  team_roles = [
    "roles/run.developer",
    "roles/datastore.user",
    "roles/artifactregistry.writer",
    "roles/logging.viewer",
  ]

  team_members = [for m in var.team_members : length(regexall(":", m)) > 0 ? m : "user:${m}"]

  team_bindings = {
    for pair in setproduct(local.team_members, local.team_roles) :
    "${pair[0]}|${pair[1]}" => { member = pair[0], role = pair[1] }
  }
}

resource "google_project_iam_member" "team" {
  for_each = local.team_bindings

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

# ---------------------------------------------------------------------------
# Public access for every deployed Cloud Run service
# ---------------------------------------------------------------------------

locals {
  public_services = merge(
    {
      mock-api   = google_cloud_run_v2_service.mock_api.name
      web        = google_cloud_run_v2_service.web.name
      family-web = google_cloud_run_v2_service.family_web.name
    },
    var.deploy_api ? { api = google_cloud_run_v2_service.api[0].name } : {},
    var.deploy_agent ? { agent = google_cloud_run_v2_service.agent[0].name } : {},
  )

  grant_all_users = var.allow_public && !var.public_via_invoker_iam_disabled
  invoker_iam_off = var.allow_public && var.public_via_invoker_iam_disabled
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  for_each = local.grant_all_users ? local.public_services : {}

  project  = var.project_id
  location = var.region
  name     = each.value
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ---------------------------------------------------------------------------
# Demo token secret (HS256 JWT signing key for mock-api).
# Plain env var is fine for a one-day demo; Secret Manager is the next step.
# ---------------------------------------------------------------------------

resource "random_password" "token_secret" {
  length  = 32
  special = false
}
