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

variable "namespace" {
  description = "Namespace to deploy the registry into."
  type        = string
  default     = "dawnfire"
}

variable "storage_class" {
  description = "Storage class for registry PVC."
  type        = string
  default     = "longhorn-bulk"
}

variable "storage_size" {
  description = "Registry PVC size. Images compress well but build up over time."
  type        = string
  default     = "20Gi"
}

variable "cert_issuer" {
  description = "cert-manager ClusterIssuer for the registry Ingress."
  type        = string
  default     = "letsencrypt-staging"
}

variable "hostname" {
  description = "Hostname for the registry Ingress."
  type        = string
  default     = "registry.dawnfire.casa"
}
