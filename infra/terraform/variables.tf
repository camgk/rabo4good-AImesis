variable "project_id" {
  description = "The GCP Project ID"
  type        = string
  default     = "qwiklabs-gcp-00-cc29ec8bfdd9"
}

variable "region" {
  description = "The primary GCP region for regional resources"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "The primary GCP zone for zonal resources"
  type        = string
  default     = "europe-west1-b"
}

variable "location_id" {
  description = "The location for the Firestore database (e.g. europe-west1, eur3, or nam5)"
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"
}
