variable "kubeconfig_path" {
  description = "Path to kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "kubeconfig context to use. Leave empty to use the current context."
  type        = string
  default     = ""
}

variable "chart_version" {
  description = "kube-prometheus-stack Helm chart version."
  type        = string
  default     = "82.0.2"
}

variable "namespace" {
  description = "Namespace to deploy the monitoring stack into."
  type        = string
  default     = "monitoring"
}

variable "grafana_hostname" {
  description = "Hostname for the Grafana Ingress."
  type        = string
  default     = "grafana.dawnfire.casa"
}

variable "prometheus_hostname" {
  description = "Hostname for the Prometheus Ingress."
  type        = string
  default     = "prometheus.dawnfire.casa"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Pass via TF_VAR_grafana_admin_password — never commit this value."
  type        = string
  sensitive   = true
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for Alertmanager notifications. Pass via TF_VAR_discord_webhook_url."
  type        = string
  sensitive   = true
}

variable "cert_issuer" {
  description = "cert-manager ClusterIssuer to use for Ingress TLS. Use letsencrypt-staging first."
  type        = string
  default     = "letsencrypt-staging"
}

variable "grafana_storage_class" {
  description = "Storage class for Grafana PVC."
  type        = string
  default     = "longhorn-duplicate"
}

variable "prometheus_storage_class" {
  description = "Storage class for Prometheus PVC."
  type        = string
  default     = "longhorn-duplicate"
}

variable "prometheus_retention" {
  description = "Prometheus data retention period."
  type        = string
  default     = "30d"
}

variable "prometheus_storage_size" {
  description = "Prometheus PVC size."
  type        = string
  default     = "20Gi"
}

variable "grafana_storage_size" {
  description = "Grafana PVC size."
  type        = string
  default     = "2Gi"
}

# Thanos sidecar — runs alongside Prometheus from day one.
# Object store config is optional: leave thanos_object_store_config empty and the
# sidecar runs in no-op mode (StoreAPI available, no block uploads).
# When Garage is ready, populate thanos_object_store_config and apply — blocks will
# start uploading without a reinstall.

variable "thanos_sidecar_enabled" {
  description = "Enable Thanos sidecar alongside Prometheus."
  type        = bool
  default     = true
}

variable "thanos_object_store_config" {
  description = "Thanos object store config YAML string. Leave empty until Garage is ready — sidecar runs in no-op mode without it."
  type        = string
  default     = ""
  sensitive   = true
}
