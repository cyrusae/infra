output "namespace" {
  description = "Namespace cert-manager was deployed into."
  value       = helm_release.cert_manager.namespace
}

output "staging_issuer_name" {
  description = "Name of the staging ClusterIssuer. Use this on Ingress resources while verifying DNS-01 works."
  value       = kubernetes_manifest.cluster_issuer_staging.manifest.metadata.name
}

output "prod_issuer_name" {
  description = "Name of the production ClusterIssuer. Use this on Ingress resources for real certificates."
  value       = kubernetes_manifest.cluster_issuer_prod.manifest.metadata.name
}
