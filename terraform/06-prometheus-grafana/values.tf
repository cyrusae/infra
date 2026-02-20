locals {
  helm_values = yamlencode({
    grafana = {
      adminPassword = var.grafana_admin_password
      persistence = {
        enabled          = true
        storageClassName = var.grafana_storage_class
        size             = var.grafana_storage_size
      }
      ingress = {
        enabled           = true
        ingressClassName  = "traefik"
        hosts             = [var.grafana_hostname]
        tls = [
          {
            secretName = "grafana-tls"
            hosts      = [var.grafana_hostname]
          }
        ]
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cert_issuer
        }
      }
    }

    prometheus = {
      ingress = {
        enabled          = true
        ingressClassName = "traefik"
        hosts            = [var.prometheus_hostname]
        tls = [
          {
            secretName = "prometheus-tls"
            hosts      = [var.prometheus_hostname]
          }
        ]
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cert_issuer
        }
      }
      prometheusSpec = {
        retention = var.prometheus_retention
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = var.prometheus_storage_class
              resources = {
                requests = {
                  storage = var.prometheus_storage_size
                }
              }
            }
          }
        }
        thanos = merge(
          {
            baseImage = "quay.io/thanos/thanos"
            version   = "v0.37.2"
          },
          var.thanos_object_store_config != "" ? {
            objectStorageConfig = {
              secret = {
                name = "thanos-objstore-config"
                key  = "objstore.yml"
              }
            }
          } : {}
        )
      }
    }
  })
}