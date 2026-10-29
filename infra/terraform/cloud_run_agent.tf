# ---------------------------------------------------------------------------
# ADK agent (backend/agent): OWNED BY TEAMMATES, OFF BY DEFAULT.
# Switch on with:
#   -var deploy_agent=true -var agent_image=europe-west1-docker.pkg.dev/<project>/aimesis/agent:<tag>
# ---------------------------------------------------------------------------

resource "google_service_account" "agent" {
  count = var.deploy_agent ? 1 : 0

  project      = var.project_id
  account_id   = "aimesis-agent"
  display_name = "AImesis agent (Cloud Run, Gemini via Vertex AI)"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "agent" {
  for_each = var.deploy_agent ? toset(["roles/aiplatform.user", "roles/logging.logWriter"]) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.agent[0].email}"
}

resource "google_cloud_run_v2_service" "agent" {
  count = var.deploy_agent ? 1 : 0

  project              = var.project_id
  name                 = "agent"
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_ALL"
  deletion_protection  = false
  invoker_iam_disabled = local.invoker_iam_off

  lifecycle {
    precondition {
      condition     = var.agent_image != ""
      error_message = "Set agent_image when deploy_agent = true."
    }
  }

  template {
    service_account = google_service_account.agent[0].email
    timeout         = "300s" # SSE streams (AG-UI)

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    containers {
      image = var.agent_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
        cpu_idle = true
      }

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "GOOGLE_CLOUD_LOCATION"
        value = "global"
      }
      env {
        name  = "GOOGLE_GENAI_USE_VERTEXAI"
        value = "TRUE"
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.agent,
  ]
}
