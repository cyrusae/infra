output "dns_ip" {
  description = "Pi-hole DNS LoadBalancer IP. Set this as primary DNS in Eero."
  value       = var.load_balancer_ip
}

output "web_url" {
  description = "Pi-hole admin panel URL."
  value       = "https://pihole.dawnfire.casa/admin"
}

output "eero_dns_config" {
  description = "DNS configuration instructions for Eero."
  value       = "Set Eero primary DNS to ${var.load_balancer_ip}, secondary to ${var.upstream_dns_1}"
}
