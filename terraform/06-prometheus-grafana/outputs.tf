output "namespace" {
  description = "Namespace the monitoring stack was deployed into."
  value       = helm_release.kube_prometheus_stack.namespace
}

output "grafana_url" {
  description = "Grafana URL."
  value       = "https://${var.grafana_hostname}"
}

output "prometheus_url" {
  description = "Prometheus URL."
  value       = "https://${var.prometheus_hostname}"
}

output "grafana_admin_user" {
  description = "Grafana admin username."
  value       = "admin"
}
