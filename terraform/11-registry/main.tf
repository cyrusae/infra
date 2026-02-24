# Docker Registry — private image registry at registry.dawnfire.casa.
#
# Apply order: Layer 5, step 2. After pihole/.
#
# No auth configured by default — registry is only accessible via Traefik Ingress
# which requires Pi-hole DNS + local network or Tailscale. If you ever expose this
# externally, add htpasswd auth before doing so.
#
# Images are stored on longhorn-bulk (single replica) — registry images can be
# rebuilt from source if lost, so durability trades off for storage efficiency.
# Bump to longhorn-duplicate if you accumulate images that are slow to rebuild.

resource "kubernetes_namespace" "dawnfire" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_persistent_volume_claim" "registry_data" {
  metadata {
    name      = "registry-data"
    namespace = kubernetes_namespace.dawnfire.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

resource "kubernetes_deployment" "registry" {
  metadata {
    name      = "registry"
    namespace = kubernetes_namespace.dawnfire.metadata[0].name
    labels = {
      app = "registry"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "registry"
      }
    }

    template {
      metadata {
        labels = {
          app = "registry"
        }
      }

      spec {
        container {
          name  = "registry"
          image = "registry:2"

          env {
            name  = "REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY"
            value = "/var/lib/registry"
          }

          port {
            container_port = 5000
            protocol       = "TCP"
          }

          volume_mount {
            name       = "registry-data"
            mount_path = "/var/lib/registry"
          }
        }

        volume {
          name = "registry-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.registry_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "registry" {
  metadata {
    name      = "registry"
    namespace = kubernetes_namespace.dawnfire.metadata[0].name
  }

  spec {
    selector = {
      app = "registry"
    }

    type = "ClusterIP"

    port {
      port        = 5000
      target_port = 5000
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "registry" {
  metadata {
    name      = "registry"
    namespace = kubernetes_namespace.dawnfire.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                   = var.cert_issuer
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-redirect-to-https@kubernetescrd"
      # Homepage service discovery annotations
      "gethomepage.dev/enabled"     = "true"
      "gethomepage.dev/name"        = "Registry"
      "gethomepage.dev/description" = "Private Docker image registry"
      "gethomepage.dev/group"       = "Infrastructure"
      "gethomepage.dev/icon"        = "docker.png"
      "gethomepage.dev/href"        = "https://${var.hostname}"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = [var.hostname]
      secret_name = "registry-tls"
    }

    rule {
      host = var.hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.registry.metadata[0].name
              port {
                number = 5000
              }
            }
          }
        }
      }
    }
  }
}
