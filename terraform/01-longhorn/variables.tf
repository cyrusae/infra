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
  description = "Longhorn Helm chart version."
  type        = string
  default     = "1.7.2"
}

variable "namespace" {
  description = "Namespace to deploy Longhorn into."
  type        = string
  default     = "longhorn-system"
}

variable "replica_count" {
  description = "Default number of Longhorn volume replicas (used for the Longhorn default storage class, not our custom tiers)."
  type        = number
  default     = 3
}

variable "storage_over_provisioning_percentage" {
  description = "Longhorn storage over-provisioning percentage."
  type        = number
  default     = 200
}

variable "storage_minimal_available_percentage" {
  description = "Longhorn will refuse to schedule replicas if available disk space drops below this percentage."
  type        = number
  default     = 10
}
