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

  # -------------------------------------------------------------------------
  # Grafana
  # -------------------------------------------------------------------------

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }

  set {
    name  = "grafana.persistence.storageClassName"
    value = var.grafana_storage_class
  }

  set {
    name  = "grafana.persistence.size"
    value = var.grafana_storage_size
  }

  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }

  set {
    name  = "grafana.ingress.ingressClassName"
    value = "traefik"
  }

  set {
    name  = "grafana.ingress.hosts[0]"
    value = var.grafana_hostname
  }

  set {
    name  = "grafana.ingress.tls[0].secretName"
    value = "grafana-tls"
  }

  set {
    name  = "grafana.ingress.tls[0].hosts[0]"
    value = var.grafana_hostname
  }

  set {
    name  = "grafana.ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = var.cert_issuer
  }

  # -------------------------------------------------------------------------
  # Prometheus
  # -------------------------------------------------------------------------

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.prometheus_retention
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = var.prometheus_storage_class
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_storage_size
  }

  set {
    name  = "prometheus.ingress.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.ingress.ingressClassName"
    value = "traefik"
  }

  set {
    name  = "prometheus.ingress.hosts[0]"
    value = var.prometheus_hostname
  }

  set {
    name  = "prometheus.ingress.tls[0].secretName"
    value = "prometheus-tls"
  }

  set {
    name  = "prometheus.ingress.tls[0].hosts[0]"
    value = var.prometheus_hostname
  }

  set {
    name  = "prometheus.ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = var.cert_issuer
  }

  # -------------------------------------------------------------------------
  # Thanos sidecar
  # -------------------------------------------------------------------------
  # Runs alongside Prometheus from day one. With no object store configured,
  # it operates in no-op mode: StoreAPI is available but no blocks are uploaded.
  # When Garage is ready, set thanos_object_store_config and re-apply —
  # the sidecar will begin uploading blocks without a reinstall.
  #
  # To activate object store later:
  #   export TF_VAR_thanos_object_store_config=$(cat garage-thanos-config.yaml)
  #   terraform apply

  set {
    name  = "prometheus.prometheusSpec.thanos.baseImage"
    value = "quay.io/thanos/thanos"
  }

  set {
    name  = "prometheus.prometheusSpec.thanos.version"
    value = "v0.37.2"
  }

  dynamic "set" {
    for_each = var.thanos_object_store_config != "" ? [1] : []
    content {
      name  = "prometheus.prometheusSpec.thanos.objectStorageConfig.secret.name"
      value = "thanos-objstore-config"
    }
  }

  dynamic "set" {
    for_each = var.thanos_object_store_config != "" ? [1] : []
    content {
      name  = "prometheus.prometheusSpec.thanos.objectStorageConfig.secret.key"
      value = "objstore.yml"
    }
  }

  # -------------------------------------------------------------------------
  # Alertmanager — Discord notifications
  # -------------------------------------------------------------------------
  # kube-prometheus-stack accepts Alertmanager config inline as a Helm value.
  # The Discord webhook URL is injected at apply time via TF_VAR_.

  set {
    name = "alertmanager.config.global.resolve_timeout"
    value = "5m"
  }

  set {
    name  = "alertmanager.config.route.group_by[0]"
    value = "alertname"
  }

  set {
    name  = "alertmanager.config.route.group_by[1]"
    value = "namespace"
  }

  set {
    name  = "alertmanager.config.route.group_wait"
    value = "30s"
  }

  set {
    name  = "alertmanager.config.route.group_interval"
    value = "5m"
  }

  set {
    name  = "alertmanager.config.route.repeat_interval"
    value = "12h"
  }

  set {
    name  = "alertmanager.config.route.receiver"
    value = "discord"
  }

  set {
    name  = "alertmanager.config.receivers[0].name"
    value = "discord"
  }

  set {
    name  = "alertmanager.config.receivers[0].discord_configs[0].webhook_url"
    value = var.discord_webhook_url
  }

  set {
    name  = "alertmanager.config.receivers[0].discord_configs[0].title"
    value = "{{ .CommonLabels.alertname }}"
  }

  set {
    name  = "alertmanager.config.receivers[0].discord_configs[0].message"
    value = "{{ range .Alerts }}{{ .Annotations.summary }}\\n{{ end }}"
  }

  # -------------------------------------------------------------------------
  # Custom homelab alert rules
  # -------------------------------------------------------------------------
  # The chart ships with comprehensive default rules for node, pod, and etcd health.
  # These additionalPrometheusRulesMap entries add homelab-specific rules on top.

  values = [
    yamlencode({
      additionalPrometheusRulesMap = {
        homelab-rules = {
          groups = [
            {
              name = "homelab.pihole"
              rules = [
                {
                  alert = "PiholeDown"
                  expr  = "kube_deployment_status_replicas_available{namespace=\"pihole\",deployment=\"pihole\"} < 1"
                  for   = "2m"
                  labels = {
                    severity = "critical"
                  }
                  annotations = {
                    summary     = "Pi-hole is down — household DNS failing"
                    description = "Pi-hole deployment has 0 available replicas for more than 2 minutes."
                  }
                }
              ]
            },
            {
              name = "homelab.longhorn"
              rules = [
                {
                  alert = "LonghornVolumeActualSpaceUsedWarning"
                  expr  = "(longhorn_volume_actual_size_bytes / longhorn_volume_capacity_bytes) > 0.80"
                  for   = "5m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary     = "Longhorn volume {{ $labels.volume }} is over 80% full"
                    description = "Volume {{ $labels.volume }} on node {{ $labels.node }} is {{ $value | humanizePercentage }} full."
                  }
                },
                {
                  alert = "LonghornVolumeDegraded"
                  expr  = "longhorn_volume_robustness == 2"
                  for   = "5m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary     = "Longhorn volume {{ $labels.volume }} is degraded"
                    description = "Volume {{ $labels.volume }} has fewer replicas than configured. Data is at risk."
                  }
                }
              ]
            },
            {
              name = "homelab.certificates"
              rules = [
                {
                  alert = "CertExpiringIn14Days"
                  expr  = "certmanager_certificate_expiration_timestamp_seconds - time() < 14 * 24 * 3600"
                  for   = "1h"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary     = "Certificate {{ $labels.name }} expires in less than 14 days"
                    description = "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} is expiring soon. cert-manager should renew automatically — check if renewal is blocked."
                  }
                }
              ]
            },
            {
              name = "homelab.etcd"
              rules = [
                {
                  # etcd commit latency spiking is the early warning sign from the Feb 2026 cascade.
                  # Default kube-prometheus-stack rules fire at higher thresholds — this one is tuned
                  # for the homelab where any sustained latency spike is worth investigating.
                  alert = "EtcdHighCommitDurations"
                  expr  = "histogram_quantile(0.99, rate(etcd_disk_backend_commit_duration_seconds_bucket[5m])) > 0.25"
                  for   = "10m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary     = "etcd commit latency elevated on {{ $labels.instance }}"
                    description = "etcd p99 commit duration is {{ $value }}s. This was an early indicator of the Feb 2026 cascade — investigate disk health on the affected node."
                  }
                }
              ]
            }
          ]
        }
      }
    })
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
