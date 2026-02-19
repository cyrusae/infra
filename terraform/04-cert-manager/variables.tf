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
  description = "cert-manager Helm chart version."
  type        = string
  default     = "v1.17.1"
}

variable "namespace" {
  description = "Namespace to deploy cert-manager into."
  type        = string
  default     = "cert-manager"
}

variable "acme_email" {
  description = "Email address for Let's Encrypt ACME account registration."
  type        = string
  default     = "cyrus@dawnfire.casa"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:Read and DNS:Edit permissions for dawnfire.casa. Create manually and pass via TF_VAR_cloudflare_api_token — never commit this value."
  type        = string
  sensitive   = true
}
