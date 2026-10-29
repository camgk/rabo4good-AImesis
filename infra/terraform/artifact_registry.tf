resource "google_artifact_registry_repository" "aimesis" {
  project       = var.project_id
  location      = var.region
  repository_id = "aimesis"
  format        = "DOCKER"
  description   = "AImesis hackathon images (mock-api, web, family-web, agent, api)"

  depends_on = [google_project_service.apis]
}

locals {
  registry = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.aimesis.repository_id}"

  mock_api_image   = var.mock_api_image != "" ? var.mock_api_image : "${local.registry}/mock-api:${var.image_tag}"
  web_image        = var.web_image != "" ? var.web_image : "${local.registry}/web:${var.image_tag}"
  family_web_image = var.family_web_image != "" ? var.family_web_image : "${local.registry}/family-web:${var.image_tag}"
}
