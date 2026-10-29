locals {
  services = [
    "firestore.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each                   = toset(locals.services)
  project                    = var.project_id
  service                    = each.key
  disable_on_destroy         = false
  disable_dependent_services = false
}
