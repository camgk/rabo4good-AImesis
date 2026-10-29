# Family app (frontend/ios) built as Flutter web: the phone-width fallback when
# no iPhone is available. Same nginx image contract as `web` (config.json from
# API_URL at container start).
resource "google_cloud_run_v2_service" "family_web" {
  project              = var.project_id
  name                 = "family-web"
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_ALL"
  deletion_protection  = false
  invoker_iam_disabled = local.invoker_iam_off

  template {
    service_account = google_service_account.web.email

    scaling {
      min_instance_count = 1
      max_instance_count = 3
    }

    containers {
      image = local.family_web_image

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
        name  = "API_URL"
        value = google_cloud_run_v2_service.mock_api.uri
      }
    }
  }

  depends_on = [google_project_service.apis]
}
