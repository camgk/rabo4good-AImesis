# Care-team web app (frontend/web): Flutter web build served by nginx.
# The container writes /config.json from API_URL at start-up.
resource "google_cloud_run_v2_service" "web" {
  project              = var.project_id
  name                 = "web"
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
      image = local.web_image

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
