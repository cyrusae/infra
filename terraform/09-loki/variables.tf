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
  description = "Loki Helm chart version (grafana/loki)."
  type        = string
  default     = "6.53.0"
}

variable "namespace" {
  description = "Namespace to deploy Loki into. Should match the monitoring namespace so Grafana can discover it as a datasource."
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
