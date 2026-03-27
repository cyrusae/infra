# Loki — log aggregation for the cluster.
#
# Apply order: Layer 4, step 2. After prometheus-grafana/.
# Grafana discovers Loki automatically as a datasource when deployed in the same namespace.
#
# Deployment mode: SingleBinary (monolithic).
# Loki has three deployment modes: monolithic, simple scalable, and microservices.
# Monolithic is correct for a 3-node homelab — simple scalable and microservices
# are for multi-tenant production deployments with much higher log volumes.
#
# Alloy is deployed as a DaemonSet (one pod per node) to collect logs from
# all containers and ship them to Loki. Alloy replaced Promtail as the official
# Grafana log collector; Promtail reached EOL in March 2026.
#
# NOTE (March 2026): The Grafana Loki Helm chart is migrating from
# grafana/helm-charts to grafana-community/helm-charts for OSS users effective
# March 16, 2026. If `helm repo update` starts returning 404s for grafana/loki,
# switch the repository URL to https://grafana-community.github.io/helm-charts
# and update the chart name accordingly.

resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana-community.github.io/helm-charts"
  chart            = "loki"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = false # Namespace created by prometheus-grafana module

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      deploymentMode = "SingleBinary"

      loki = {
        commonConfig = {
          replication_factor = 1
        }
        storage = {
          type = "filesystem"
        }
        schemaConfig = {
          configs = [
            {
              from         = "2024-01-01"
              store        = "tsdb"
              object_store = "filesystem"
              schema       = "v13"
              index = {
                prefix = "loki_index_"
                period = "24h"
              }
            }
          ]
        }
        limits_config = {
          retention_period = var.retention_period
        }
        compactor = {
          retention_enabled    = true
          delete_request_store = var.delete_request_store
        }
      }

      singleBinary = {
        replicas = 1
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }
      }

      # Disable components that are only needed for scalable/microservices mode
      read    = { replicas = 0 }
      write   = { replicas = 0 }
      backend = { replicas = 0 }

      # Grafana datasource auto-provisioning
      # Grafana will discover this as a Loki datasource via the sidecar
      gateway = {
        enabled = false # Not needed for single-binary homelab
      }
    })
  ]
}

# Alloy — DaemonSet log collector, ships logs from all nodes to Loki.
#
# Alloy uses a River/Alloy config DSL (not YAML). The config is embedded via
# the alloy.configMap.content value as a heredoc-style string in yamlencode.
#
# Pipeline:
#   discovery.kubernetes (pod role)
#     → discovery.relabel (add useful labels, drop system noise)
#       → loki.source.kubernetes (tail pod logs)
#         → loki.write (push to Loki)
#
# varlog mount is NOT needed for this pipeline — loki.source.kubernetes reads
# from the Kubernetes API / container runtime directly, not from /var/log on
# the host. Only needed if you also want node syslog/journal collection (see
# var.collect_node_logs).

resource "helm_release" "alloy" {
  name       = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.alloy_chart_version
  namespace  = var.namespace

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      alloy = {
        # varlog mount: only needed for node-level log collection (syslog, journal).
        # Pod log collection via loki.source.kubernetes does not require it.
        mounts = {
          varlog = var.collect_node_logs
        }

        configMap = {
          content = <<-ALLOY
            // ── Loki write endpoint ──────────────────────────────────────────
            loki.write "default" {
              endpoint {
                url = "http://loki.${var.namespace}.svc.cluster.local:3100/loki/api/v1/push"
              }
            }

            // ── Pod log collection ───────────────────────────────────────────
            // Discover all pods across all namespaces.
            discovery.kubernetes "pods" {
              role = "pod"
            }

            // Relabel: extract useful metadata as Loki labels, drop high-cardinality
            // labels that would bloat the index, and skip Completed/evicted pods.
            discovery.relabel "pod_logs" {
              targets = discovery.kubernetes.pods.targets

              // Keep namespace as a label
              rule {
                source_labels = ["__meta_kubernetes_namespace"]
                target_label  = "namespace"
              }

              // Keep pod name
              rule {
                source_labels = ["__meta_kubernetes_pod_name"]
                target_label  = "pod"
              }

              // Keep container name
              rule {
                source_labels = ["__meta_kubernetes_pod_container_name"]
                target_label  = "container"
              }

              // Derive app label: prefer app.kubernetes.io/name, fall back to app
              rule {
                source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
                target_label  = "app"
              }
              rule {
                source_labels = ["app", "__meta_kubernetes_pod_label_app"]
                regex         = ";(.+)"
                target_label  = "app"
              }

              // Drop pods in Completed/Succeeded phase — they have no live logs
              rule {
                source_labels = ["__meta_kubernetes_pod_phase"]
                regex         = "Succeeded|Failed"
                action        = "drop"
              }
            }

            // Tail logs for all discovered pods
            loki.source.kubernetes "pod_logs" {
              targets    = discovery.relabel.pod_logs.output
              forward_to = [loki.write.default.receiver]
            }

            ${var.collect_node_logs ? local.node_log_config : "// Node log collection disabled (var.collect_node_logs = false)"}
          ALLOY
        }
      }

      # Run as DaemonSet so every node ships its own pod logs
      controller = {
        type = "daemonset"
      }
    })
  ]

  depends_on = [helm_release.loki]
}

# Node log config fragment — only used when collect_node_logs = true.
# Reads /var/log/syslog from each node (requires varlog mount above).
locals {
  node_log_config = <<-ALLOY
    // ── Node syslog collection ───────────────────────────────────────────
    local.file_match "node_logs" {
      path_targets = [{
        __path__ = "/var/log/syslog",
        job       = "node/syslog",
        node_name = sys.env("HOSTNAME"),
      }]
    }

    loki.source.file "node_logs" {
      targets    = local.file_match.node_logs.targets
      forward_to = [loki.write.default.receiver]
    }
  ALLOY
}
