# Demo backend (backend/mock_api): FastAPI + Firestore with mock UZA v2 rules,
# so the frontends run today while the real agent/api are being built.
resource "google_cloud_run_v2_service" "mock_api" {
  project              = var.project_id
  name                 = "mock-api"
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_ALL"
  deletion_protection  = false
  invoker_iam_disabled = local.invoker_iam_off

  template {
    service_account = google_service_account.mock_api.email

    scaling {
      min_instance_count = 1 # keep warm during the demo
      max_instance_count = 3
    }

    containers {
      image = local.mock_api_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "FIRESTORE_DATABASE"
        value = google_firestore_database.default.name
      }
      env {
        name  = "STORE"
        value = "firestore"
      }
      env {
        name  = "SEED_ON_START"
        value = "true"
      }
      env {
        # Demo only. Next step: Secret Manager + secret_key_ref.
        name  = "TOKEN_SECRET"
        value = random_password.token_secret.result
      }

      startup_probe {
        http_get {
          path = "/healthz"
        }
        initial_delay_seconds = 2
        period_seconds        = 5
        timeout_seconds       = 3
        failure_threshold     = 24
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_firestore_database.default,
    google_project_iam_member.mock_api,
  ]
}
