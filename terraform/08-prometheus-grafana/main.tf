# kube-prometheus-stack — Prometheus, Grafana, Alertmanager, and exporters.
#
# Apply order: Layer 4, step 1. After all Layer 3 modules.
# Monitoring before services: this stack must be healthy before any Layer 5 services are deployed.
#
# Secrets passed via environment variables:
#   export TF_VAR_grafana_admin_password="..."
#   export TF_VAR_discord_webhook_url="https://discord.com/api/webhooks/..."
#
# cert_issuer defaults to letsencrypt-staging — switch to letsencrypt-prod once
# you've verified the stack is healthy and certs are issuing correctly.

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  wait    = true
  timeout = 600 # Large chart with many CRDs — takes a while on first install

  values = [
    local.helm_values,
    local.alertmanager_values,
    local.custom_rules_values,
  ]
}

# Object store secret — only created when thanos_object_store_config is provided.
# The Thanos sidecar references this secret by name once the object store is configured.
# Create the secret before pointing thanos.objectStorageConfig at it.
#
# Example objstore.yml for Garage (S3-compatible):
#   type: S3
#   config:
#     bucket: thanos
#     endpoint: garage.dawnfire.casa:3900
#     access_key: <key>
#     secret_key: <secret>
#     insecure: false
resource "kubernetes_secret" "thanos_objstore_config" {
  count = var.thanos_object_store_config != "" ? 1 : 0

  metadata {
    name      = "thanos-objstore-config"
    namespace = var.namespace
  }

  data = {
    "objstore.yml" = var.thanos_object_store_config
  }

  type = "Opaque"

  depends_on = [helm_release.kube_prometheus_stack]
}