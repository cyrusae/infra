output "url" {
  description = "Letta API URL."
  value       = "https://${var.hostname}"
}

output "namespace" {
  description = "Namespace Letta was deployed into."
  value       = kubernetes_namespace.letta.metadata[0].name
}

output "db_pvc_name" {
  description = "Name of the PostgreSQL/pgvector PVC. Back this up before any cluster maintenance."
  value       = kubernetes_persistent_volume_claim.letta_db.metadata[0].name
}

output "db_service_host" {
  description = "Cluster-internal hostname for the PostgreSQL service."
  value       = "${kubernetes_service.letta_db.metadata[0].name}.${var.namespace}.svc.cluster.local"
}

output "api_base_url" {
  description = "Letta API base URL for use in SDK clients."
  value       = "https://${var.hostname}"
}
