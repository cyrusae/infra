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
  description = "Traefik Helm chart version."
  type        = string
  default     = "33.2.1"
}

variable "namespace" {
  description = "Namespace to deploy Traefik into."
  type        = string
  default     = "traefik"
}

variable "load_balancer_ip" {
  description = "Static IP for the Traefik LoadBalancer service. Must be within the MetalLB pool."
  type        = string
  default     = "192.168.4.240"
}
