output "display_url" {
  description = "Bedroom Display URL (bedroom TV display)."
  value       = var.display_enabled ? "https://${var.display_hostname}" : "disabled"
}

output "remote_url" {
  description = "Epimetheus Remote URL (mobile control interface)."
  value       = var.remote_enabled ? "https://${var.remote_hostname}" : "disabled"
}

output "namespace" {
  description = "Namespace dashboards were deployed into."
  value       = kubernetes_namespace.dashboards.metadata[0].name
}

output "registry_catalog_check" {
  description = "Command to verify images exist before applying."
  value       = "curl https://registry.dawnfire.casa/v2/_catalog"
}
