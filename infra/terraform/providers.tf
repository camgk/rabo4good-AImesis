terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # Bill API calls made with user credentials to the lab project itself, so
  # Firestore / Service Usage don't complain about a missing quota project.
  user_project_override = true
  billing_project       = var.project_id

  default_labels = {
    app        = "aimesis"
    managed_by = "terraform"
    purpose    = "hackathon-demo"
  }
}

data "google_project" "this" {
  project_id = var.project_id
}
