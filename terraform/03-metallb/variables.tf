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
  description = "MetalLB Helm chart version."
  type        = string
  default     = "0.15.3"
}

variable "namespace" {
  description = "Namespace to deploy MetalLB into."
  type        = string
  default     = "metallb-system"
}

variable "ip_pool_range" {
  description = "IP address range MetalLB may assign to LoadBalancer services. Must be outside the Eero DHCP pool (which ends at 192.168.4.239)."
  type        = string
  default     = "192.168.4.240-192.168.4.254"
}

variable "ip_pool_name" {
  description = "Name of the MetalLB IPAddressPool resource."
  type        = string
  default     = "default-pool"
}
