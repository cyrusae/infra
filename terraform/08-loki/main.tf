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
# Promtail is deployed as a DaemonSet (one pod per node) to collect logs from
# all containers and ship them to Loki.

resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
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
          retention_enabled = true
        }
      }

      singleBinary = {
        replicas = 1
        persistence = {
          enabled          = true
          storageClass     = var.storage_class
          size             = var.storage_size
        }
      }

      # Disable components that are only needed for scalable/microservices mode
      read  = { replicas = 0 }
      write = { replicas = 0 }
      backend = { replicas = 0 }

      # Grafana datasource auto-provisioning
      # Grafana will discover this as a Loki datasource via the sidecar
      gateway = {
        enabled = false # Not needed for single-binary homelab
      }
    })
  ]
}

# Promtail — DaemonSet log collector, ships logs from all nodes to Loki
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.16.6"
  namespace  = var.namespace

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      config = {
        clients = [
          {
            # Loki service URL within the cluster
            url = "http://loki.${var.namespace}.svc.cluster.local:3100/loki/api/v1/push"
          }
        ]
      }
    })
  ]

  depends_on = [helm_release.loki]
}
