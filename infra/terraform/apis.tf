locals {
  services = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "firestore.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com", # creates the compute default SA Cloud Build runs as
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "aiplatform.googleapis.com", # teammates' Gemini agent
    "storage.googleapis.com",
  ])
}

resource "google_project_service" "apis" {
  for_each = local.services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
