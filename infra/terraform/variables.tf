variable "project_id" {
  description = "GCP project to deploy into (the Qwiklabs hackathon project)."
  type        = string
}

variable "region" {
  description = "Region for Cloud Run, Artifact Registry and Firestore."
  type        = string
  default     = "europe-west1"
}

variable "image_tag" {
  description = "Image tag for the demo images (deploy.sh passes <git sha>-<timestamp>)."
  type        = string
}

# ---------------------------------------------------------------------------
# Image overrides. Empty string = ${region}-docker.pkg.dev/${project}/aimesis/<name>:${image_tag}
# ---------------------------------------------------------------------------

variable "mock_api_image" {
  description = "Full image reference for the mock-api service. Empty = derived from image_tag."
  type        = string
  default     = ""
}

variable "web_image" {
  description = "Full image reference for the care-team web app. Empty = derived from image_tag."
  type        = string
  default     = ""
}

variable "family_web_image" {
  description = "Full image reference for the family app (Flutter web build). Empty = derived from image_tag."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Teammates' real services (off by default)
# ---------------------------------------------------------------------------

variable "deploy_agent" {
  description = "Deploy the ADK agent service (backend/agent). Owned by teammates."
  type        = bool
  default     = false
}

variable "agent_image" {
  description = "Full image reference for the agent service. Required when deploy_agent = true."
  type        = string
  default     = ""
}

variable "deploy_api" {
  description = "Deploy the real REST API service (backend/api). Owned by teammates."
  type        = bool
  default     = false
}

variable "api_image" {
  description = "Full image reference for the api service. Required when deploy_api = true."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Access
# ---------------------------------------------------------------------------

variable "team_members" {
  description = "Teammate Google accounts (e.g. \"someone@gmail.com\" or \"user:someone@gmail.com\") that get developer roles on the project."
  type        = list(string)
  default     = []
}

variable "allow_public" {
  description = "Make the Cloud Run services publicly reachable (no login) for the demo."
  type        = bool
  default     = true
}

variable "public_via_invoker_iam_disabled" {
  description = "Fallback if an org policy (domain-restricted sharing) blocks allUsers: make services public by disabling the Cloud Run invoker IAM check instead of granting roles/run.invoker to allUsers."
  type        = bool
  default     = false
}

variable "grant_legacy_cloudbuild_sa" {
  description = "Also grant build roles to the legacy Cloud Build SA (<number>@cloudbuild.gserviceaccount.com). Set false if that SA does not exist in the project."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Shared settings from the Firestore setup (PR #3)
# ---------------------------------------------------------------------------

variable "zone" {
  description = "Primary GCP zone for zonal resources."
  type        = string
  default     = "europe-west1-b"
}

variable "location_id" {
  description = "Location of the Firestore database (e.g. europe-west1, eur3)."
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}
