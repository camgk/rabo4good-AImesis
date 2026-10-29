# The team's shared Firestore database: the "(default)" database introduced in
# PR #3 (patients, passports, episodes; schemas in contracts/schemas/). It
# already exists in the lab project, so Terraform adopts it with an import
# block instead of creating it.
#
# deletion_policy = "ABANDON": `terraform destroy` removes the database from
# state but never deletes it or its data. Demo records live in this database
# tagged "demo" and are loaded / cleared with backend/mock_api/scripts/.
import {
  to = google_firestore_database.default
  id = "projects/${var.project_id}/databases/(default)"
}

resource "google_firestore_database" "default" {
  project                 = var.project_id
  name                    = "(default)"
  location_id             = var.location_id
  type                    = "FIRESTORE_NATIVE"
  delete_protection_state = "DELETE_PROTECTION_DISABLED"
  deletion_policy         = "ABANDON"

  depends_on = [google_project_service.apis]
}
