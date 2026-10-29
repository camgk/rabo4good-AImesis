output "mock_api_url" {
  description = "Base URL of the demo backend (mock-api)."
  value       = google_cloud_run_v2_service.mock_api.uri
}

output "web_url" {
  description = "Care-team web app."
  value       = google_cloud_run_v2_service.web.uri
}

output "family_web_url" {
  description = "Family app (Flutter web, open at phone width)."
  value       = google_cloud_run_v2_service.family_web.uri
}

output "api_url" {
  description = "Teammates' REST API, when deploy_api = true."
  value       = var.deploy_api ? google_cloud_run_v2_service.api[0].uri : null
}

output "agent_url" {
  description = "Teammates' ADK agent, when deploy_agent = true."
  value       = var.deploy_agent ? google_cloud_run_v2_service.agent[0].uri : null
}

output "firestore_database" {
  description = "Named Firestore database used by mock-api."
  value       = google_firestore_database.default.name
}

output "artifact_registry" {
  description = "Docker registry prefix for images."
  value       = local.registry
}

output "token_secret" {
  description = "JWT signing key of mock-api."
  value       = random_password.token_secret.result
  sensitive   = true
}

# Used by infra/scripts/deploy.sh (--only / --skip-build) to keep the images
# of services that are not being rebuilt.
output "image_tag" {
  description = "Image tag of the last apply."
  value       = var.image_tag
}

output "mock_api_image" {
  description = "Image currently deployed to mock-api."
  value       = local.mock_api_image
}

output "web_image" {
  description = "Image currently deployed to web."
  value       = local.web_image
}

output "family_web_image" {
  description = "Image currently deployed to family-web."
  value       = local.family_web_image
}

output "firestore_database_name" {
  description = "The name of the Firestore database"
  value       = google_firestore_database.default.name
}

output "firestore_location" {
  description = "The location of the Firestore database"
  value       = google_firestore_database.default.location_id
}

output "firestore_type" {
  description = "The type of the Firestore database"
  value       = google_firestore_database.default.type
}
