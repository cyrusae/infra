output "url" {
  description = "Homepage URL."
  value       = "https://${var.hostname}"
}

output "namespace" {
  description = "Namespace Homepage was deployed into."
  value       = var.namespace
}
