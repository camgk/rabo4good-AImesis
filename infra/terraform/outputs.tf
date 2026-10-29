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
