output "url" {
  description = "Nextcloud URL."
  value       = "https://${var.hostname}"
}

output "namespace" {
  description = "Namespace Nextcloud was deployed into."
  value       = kubernetes_namespace_v1.nextcloud.metadata[0].name
}

output "data_pvc_name" {
  description = "Name of the Nextcloud data PVC — needed for backup and restore procedures."
  value       = kubernetes_persistent_volume_claim_v1.nextcloud_data.metadata[0].name
}

output "db_pvc_name" {
  description = "Name of the PostgreSQL database PVC."
  value       = kubernetes_persistent_volume_claim_v1.nextcloud_db.metadata[0].name
}
