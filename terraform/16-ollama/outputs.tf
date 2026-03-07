output "cluster_internal_url" {
  description = "Cluster-internal Ollama API URL. Use this as ollama_base_url in the letta/ module."
  value       = "http://ollama.${var.namespace}.svc.cluster.local:11434"
}

output "external_url" {
  description = "External Ollama API URL (only if expose_ingress = true)."
  value       = var.expose_ingress ? "https://${var.hostname}" : "(ingress disabled)"
}

output "namespace" {
  description = "Namespace Ollama was deployed into."
  value       = kubernetes_namespace.ollama.metadata[0].name
}

output "models_pvc_name" {
  description = "Name of the model weights PVC."
  value       = kubernetes_persistent_volume_claim.ollama_models.metadata[0].name
}

output "post_deploy_commands" {
  description = "Commands to run after first apply to pull recommended models."
  value       = <<-EOT
    # Pull the embedding model (required for Letta archival memory):
    kubectl exec -n ${var.namespace} deploy/ollama -- ollama pull nomic-embed-text

    # Verify models available:
    kubectl exec -n ${var.namespace} deploy/ollama -- ollama list

    # Test the embedding endpoint:
    curl http://localhost:11434/api/embeddings \
      -d '{"model": "nomic-embed-text", "prompt": "hello world"}'
    # (run from inside the cluster or via kubectl port-forward)
  EOT
}
