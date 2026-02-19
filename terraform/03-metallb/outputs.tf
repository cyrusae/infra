output "namespace" {
  description = "Namespace MetalLB was deployed into."
  value       = helm_release.metallb.namespace
}

output "ip_pool_range" {
  description = "IP address range available for LoadBalancer services."
  value       = var.ip_pool_range
}

output "ip_pool_name" {
  description = "Name of the MetalLB IPAddressPool."
  value       = var.ip_pool_name
}

# Assigned IPs (per service) are not tracked here — they're assigned dynamically
# by MetalLB and visible via: kubectl get svc -A | grep LoadBalancer
