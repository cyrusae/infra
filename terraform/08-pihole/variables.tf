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
  description = "Namespace to deploy Pi-hole into."
  type        = string
  default     = "pihole"
}

variable "pihole_password" {
  description = "Pi-hole admin panel password. Pass via TF_VAR_pihole_password — never commit this value."
  type        = string
  sensitive   = true
}

variable "upstream_dns_1" {
  description = "Primary upstream DNS server Pi-hole forwards to."
  type        = string
  default     = "1.1.1.1"
}

variable "upstream_dns_2" {
  description = "Secondary upstream DNS server Pi-hole forwards to."
  type        = string
  default     = "8.8.8.8"
}

variable "timezone" {
  description = "Timezone for Pi-hole container."
  type        = string
  default     = "America/New_York"
}

variable "load_balancer_ip" {
  description = "Static IP for the Pi-hole DNS LoadBalancer service. Must be within the MetalLB pool."
  type        = string
  default     = "192.168.4.241"
}

variable "traefik_ip" {
  description = "Traefik LoadBalancer IP — used in Pi-hole's custom DNS entry for *.dawnfire.casa resolution."
  type        = string
  default     = "192.168.4.240"
}

variable "storage_class" {
  description = "Storage class for Pi-hole PVCs."
  type        = string
  default     = "longhorn-duplicate"
}

variable "config_storage_size" {
  description = "Size of the Pi-hole config PVC."
  type        = string
  default     = "1Gi"
}

variable "dnsmasq_storage_size" {
  description = "Size of the Pi-hole dnsmasq PVC."
  type        = string
  default     = "500Mi"
}

variable "cert_issuer" {
  description = "cert-manager ClusterIssuer for the Pi-hole web UI Ingress."
  type        = string
  default     = "letsencrypt-staging"
}
