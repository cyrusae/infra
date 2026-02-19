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
  description = "Namespace to deploy Homepage into."
  type        = string
  default     = "dawnfire"
}

variable "hostname" {
  description = "Hostname for the Homepage Ingress."
  type        = string
  default     = "homepage.dawnfire.casa"
}

variable "cert_issuer" {
  description = "cert-manager ClusterIssuer for the Homepage Ingress."
  type        = string
  default     = "letsencrypt-staging"
}

variable "title" {
  description = "Browser tab title for Homepage."
  type        = string
  default     = "dawnfire.casa"
}
