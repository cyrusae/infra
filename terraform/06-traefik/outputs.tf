output "namespace" {
  description = "Namespace Traefik was deployed into."
  value       = helm_release.traefik.namespace
}

output "load_balancer_ip" {
  description = "LoadBalancer IP assigned to Traefik. All *.dawnfire.casa DNS should point here."
  value       = var.load_balancer_ip
}

output "redirect_middleware_ref" {
  description = "Middleware reference string for HTTP→HTTPS redirect. Use in Ingress annotations."
  value       = "${var.namespace}-${kubernetes_manifest.redirect_middleware.manifest.metadata.name}@kubernetescrd"
}
