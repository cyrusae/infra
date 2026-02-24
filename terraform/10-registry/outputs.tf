output "registry_url" {
  description = "Registry URL for docker push/pull and K3s image pulls."
  value       = var.hostname
}

output "namespace" {
  description = "Namespace the registry was deployed into."
  value       = kubernetes_namespace.dawnfire.metadata[0].name
}
