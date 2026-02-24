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
  description = "Namespace for dashboard services."
  type        = string
  default     = "dashboards"
}

variable "registry" {
  description = "Registry hostname for custom images."
  type        = string
  default     = "registry.dawnfire.casa"
}

variable "cert_issuer" {
  description = "cert-manager ClusterIssuer for Ingress resources."
  type        = string
  default     = "letsencrypt-staging"
}

# -------------------------------------------------------------------------
# Bedroom Display
# -------------------------------------------------------------------------

variable "display_enabled" {
  description = "Deploy the bedroom display. Set false to skip if image isn't built yet."
  type        = bool
  default     = true
}

variable "display_image" {
  description = "Image name (without registry prefix) for the bedroom display."
  type        = string
  default     = "bedroom-display"
}

variable "display_image_tag" {
  description = "Image tag for the bedroom display. Pin to a specific tag in production."
  type        = string
  default     = "latest"
}

variable "display_hostname" {
  description = "Hostname for the bedroom display Ingress."
  type        = string
  default     = "display.dawnfire.casa"
}

variable "display_node_selector" {
  description = "Node name to pin the bedroom display pod to (the node connected to the bedroom TV). Should be Epimetheus."
  type        = string
  default     = "epimetheus"
}

# -------------------------------------------------------------------------
# Epimetheus Remote
# -------------------------------------------------------------------------

variable "remote_enabled" {
  description = "Deploy Epimetheus Remote. Set false to skip if image isn't built yet."
  type        = bool
  default     = true
}

variable "remote_image" {
  description = "Image name (without registry prefix) for Epimetheus Remote."
  type        = string
  default     = "epimetheus-remote"
}

variable "remote_image_tag" {
  description = "Image tag for Epimetheus Remote."
  type        = string
  default     = "latest"
}

variable "remote_hostname" {
  description = "Hostname for the Epimetheus Remote Ingress."
  type        = string
  default     = "remote.dawnfire.casa"
}
