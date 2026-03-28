
# Outputs
output "grobid_namespace" {
  description = "Kubernetes namespace where GROBID is deployed"
  value       = kubernetes_namespace_v1.grobid.metadata[0].name
}

output "grobid_service_name" {
  description = "Kubernetes service name for GROBID"
  value       = kubernetes_service_v1.grobid_lb.metadata[0].name
}

output "grobid_ingress_host" {
  description = "GROBID web UI hostname"
  value       = "grobid.${var.domain}"
}

output "grobid_service_url" {
  description = "Direct LoadBalancer service endpoint (internal)"
  value       = "http://${kubernetes_service_v1.grobid_lb.metadata[0].name}.${kubernetes_namespace_v1.grobid.metadata[0].name}.svc.cluster.local:8070"
}

output "grobid_api_endpoint" {
  description = "GROBID REST API endpoint"
  value       = "http://grobid.${var.domain}/api"
}

output "grobid_storage_pvc" {
  description = "Persistent Volume Claim for GROBID data"
  value       = kubernetes_persistent_volume_claim_v1.grobid.metadata[0].name
}
