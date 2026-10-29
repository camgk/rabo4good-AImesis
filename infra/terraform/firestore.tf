# Named database so we never clash with an existing "(default)" database in
# the lab project. Demo data only; deleted on `terraform destroy`.
resource "google_firestore_database" "demo" {
  project                 = var.project_id
  name                    = "aimesis-demo"
  location_id             = var.region
  type                    = "FIRESTORE_NATIVE"
  deletion_policy         = "DELETE"
  delete_protection_state = "DELETE_PROTECTION_DISABLED"

  depends_on = [google_project_service.apis]
}
