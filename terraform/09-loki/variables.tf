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
  description = "Loki Helm chart version (grafana/loki). NOTE: Loki OSS chart is migrating to grafana-community/helm-charts as of March 16, 2026 — pin this and check for repo changes."
  type        = string
  default     = "9.3.3"
}

variable "alloy_chart_version" {
  description = "Grafana Alloy Helm chart version (grafana/alloy). Alloy replaces Promtail (EOL March 2026)."
  type        = string
  default     = "1.14.2"
}

variable "namespace" {
  description = "Namespace to deploy Loki and Alloy into. Should match the monitoring namespace so Grafana can discover Loki as a datasource."
  type        = string
  default     = "monitoring"
}

variable "storage_class" {
  description = "Storage class for Loki PVC."
  type        = string
  default     = "longhorn-bulk"
}

variable "storage_size" {
  description = "Loki PVC size. Logs compress well — 10Gi covers a long time for a 3-node homelab."
  type        = string
  default     = "10Gi"
}

variable "retention_period" {
  description = "Log retention period. Loki uses a duration string."
  type        = string
  default     = "744h" # 31 days
}

variable "collect_node_logs" {
  description = "Whether to also collect node-level syslog via /var/log/syslog on each node. Requires varlog host mount. Pod log collection works without this."
  type        = bool
  default     = false
}
