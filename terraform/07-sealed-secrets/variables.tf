###############################################################################
# terraform/sealed-secrets/variables.tf
###############################################################################
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
  type        = string
  description = "Helm chart version for sealed-secrets. Pin this and update deliberately."
  default     = "2.18.1"
}
