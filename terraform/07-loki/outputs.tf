output "loki_endpoint" {
  description = "Loki push endpoint (internal cluster URL). Used by Promtail and any other log shippers."
  value       = "http://loki.${var.namespace}.svc.cluster.local:3100/loki/api/v1/push"
}

output "grafana_datasource_url" {
  description = "Loki URL to configure as a Grafana datasource (if not auto-provisioned)."
  value       = "http://loki.${var.namespace}.svc.cluster.local:3100"
}
