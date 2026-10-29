# ---------------------------------------------------------------------------
# Real REST API (backend/api): OWNED BY TEAMMATES, OFF BY DEFAULT.
# Switch on with:
#   -var deploy_api=true -var api_image=europe-west1-docker.pkg.dev/<project>/aimesis/api:<tag>
# ---------------------------------------------------------------------------

resource "google_service_account" "api" {
  count = var.deploy_api ? 1 : 0

  project      = var.project_id
  account_id   = "aimesis-api"
  display_name = "AImesis api (Cloud Run)"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "api" {
  for_each = var.deploy_api ? toset(["roles/datastore.user", "roles/logging.logWriter"]) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.api[0].email}"
}

resource "google_cloud_run_v2_service" "api" {
  count = var.deploy_api ? 1 : 0

  project              = var.project_id
  name                 = "api"
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_ALL"
  deletion_protection  = false
  invoker_iam_disabled = local.invoker_iam_off

  lifecycle {
    precondition {
      condition     = var.api_image != ""
      error_message = "Set api_image when deploy_api = true."
    }
  }

  template {
    service_account = google_service_account.api[0].email

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    containers {
      image = var.api_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "FIRESTORE_DATABASE"
        value = google_firestore_database.demo.name
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_firestore_database.demo,
    google_project_iam_member.api,
  ]
}
