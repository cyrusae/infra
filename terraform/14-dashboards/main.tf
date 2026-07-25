# Dashboards — bedroom TV displays and remote control interface.
#
# Apply order: Layer 5, step 5 (last). After all other Layer 5 modules.
#
# ⚠️  CUSTOM IMAGES — READ BEFORE APPLYING ⚠️
# Both services use images built locally and pushed to registry.dawnfire.casa.
# Terraform deploys infrastructure only — it cannot build images.
# If images don't exist in the registry, pods will enter ImagePullBackOff.
# This is exactly what caused the Session 9 failure.
#
# Before applying, confirm images are in the registry:
#   curl https://registry.dawnfire.casa/v2/_catalog
#   # Should show: {"repositories":["bedroom-display","epimetheus-remote"]}
#
# If images are missing, build and push them first:
#   cd ~/projects/bedroom-display && ./deploy.sh
#   cd ~/projects/epimetheus-remote && ./deploy.sh
#
# Both services can be individually disabled via display_enabled / remote_enabled
# variables while you get images sorted.
#

# -------------------------------------------------------------------------
# Namespace
# -------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "dashboards" {
  metadata {
    name = var.namespace
  }
}

# -------------------------------------------------------------------------
# Bedroom Display
# -------------------------------------------------------------------------

resource "kubernetes_deployment_v1" "bedroom_display" {
  count = var.display_enabled ? 1 : 0

  metadata {
    name      = "bedroom-display"
    namespace = kubernetes_namespace_v1.dashboards.metadata[0].name
    labels = {
      app = "bedroom-display"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "bedroom-display"
      }
    }

    template {
      metadata {
        labels = {
          app = "bedroom-display"
        }
      }

      spec {

        container {
          name  = "bedroom-display"
          image = "${var.registry}/${var.display_image}:${var.display_image_tag}"

          # Always pull so 'latest' tag actually picks up new builds.
          # Pin to a digest or semver tag to avoid unexpected updates.
          image_pull_policy = "Always"

          port {
            container_port = 3000
            protocol       = "TCP"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 3000
            }
            initial_delay_seconds = 15
            period_seconds        = 30
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "bedroom_display" {
  count = var.display_enabled ? 1 : 0

  metadata {
    name      = "bedroom-display"
    namespace = kubernetes_namespace_v1.dashboards.metadata[0].name
  }

  spec {
    selector = {
      app = "bedroom-display"
    }

    type = "ClusterIP"

    port {
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "bedroom_display" {
  count = var.display_enabled ? 1 : 0

  metadata {
    name      = "bedroom-display"
    namespace = kubernetes_namespace_v1.dashboards.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                   = var.cert_issuer
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-redirect-to-https@kubernetescrd"
      # Homepage discovery
      "gethomepage.dev/enabled"     = "true"
      "gethomepage.dev/name"        = "Bedroom Display"
      "gethomepage.dev/description" = "Bedroom TV display"
      "gethomepage.dev/group"       = "Personal"
      "gethomepage.dev/icon"        = "mdi-television"
      "gethomepage.dev/href"        = "https://${var.display_hostname}"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = [var.display_hostname]
      secret_name = "bedroom-display-tls"
    }

    rule {
      host = var.display_hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.bedroom_display[0].metadata[0].name
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}

# -------------------------------------------------------------------------
# Epimetheus Remote
# -------------------------------------------------------------------------
# Mobile-friendly interface for controlling the bedroom TV display mode
# (morning / afternoon / evening / TV modes, etc.).
# Not pinned to Epimetheus — runs anywhere and survives Epimetheus downtime.

resource "kubernetes_deployment_v1" "epimetheus_remote" {
  count = var.remote_enabled ? 1 : 0

  metadata {
    name      = "epimetheus-remote"
    namespace = kubernetes_namespace_v1.dashboards.metadata[0].name
    labels = {
      app = "epimetheus-remote"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "epimetheus-remote"
      }
    }

    template {
      metadata {
        labels = {
          app = "epimetheus-remote"
        }
      }

      spec {
        container {
          name  = "epimetheus-remote"
          image = "${var.registry}/${var.remote_image}:${var.remote_image_tag}"

          image_pull_policy = "Always"

          port {
            container_port = 3000
            protocol       = "TCP"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 3000
            }
            initial_delay_seconds = 15
            period_seconds        = 30
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "epimetheus_remote" {
  count = var.remote_enabled ? 1 : 0

  metadata {
    name      = "epimetheus-remote"
    namespace = kubernetes_namespace_v1.dashboards.metadata[0].name
  }

  spec {
    selector = {
      app = "epimetheus-remote"
    }

    type = "ClusterIP"

    port {
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "epimetheus_remote" {
  count = var.remote_enabled ? 1 : 0

  metadata {
    name      = "epimetheus-remote"
    namespace = kubernetes_namespace_v1.dashboards.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                   = var.cert_issuer
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-redirect-to-https@kubernetescrd"
      # Homepage discovery
      "gethomepage.dev/enabled"     = "true"
      "gethomepage.dev/name"        = "Epimetheus Remote"
      "gethomepage.dev/description" = "Bedroom TV remote control"
      "gethomepage.dev/group"       = "Personal"
      "gethomepage.dev/icon"        = "mdi-remote"
      "gethomepage.dev/href"        = "https://${var.remote_hostname}"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = [var.remote_hostname]
      secret_name = "epimetheus-remote-tls"
    }

    rule {
      host = var.remote_hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.epimetheus_remote[0].metadata[0].name
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}
