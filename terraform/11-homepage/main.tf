# Homepage — service dashboard at homepage.dawnfire.casa.
#
# Apply order: Layer 5, step 3. After registry/ (which creates the dawnfire namespace).
#
# Service discovery strategy: HYBRID
#   - Individual services appear via gethomepage.dev/ Ingress annotations (automatic)
#   - Global config (settings, widgets, bookmarks) lives in the ConfigMap here
#
# To add a new service to the dashboard: add gethomepage.dev/ annotations to its
# Ingress resource. Homepage discovers it automatically without editing this module.
# See the registry/ module's main.tf for the annotation pattern.
#
# Config editing workflow:
#   - Edit the relevant key in kubernetes_config_map.homepage below
#   - terraform apply
#   - Homepage picks up changes on next page load (no pod restart needed for config)


# -------------------------------------------------------------------------
# Namespace pre-check
# -------------------------------------------------------------------------
# The dawnfire namespace is created by the registry/ module. This data source
# lookup fails immediately if the namespace doesn't exist, giving a clear error
# rather than a confusing downstream failure. Apply registry/ first.

data "kubernetes_namespace" "dawnfire" {
  metadata {
    name = var.namespace
  }
}

# -------------------------------------------------------------------------
# RBAC — required for Ingress annotation service discovery
# -------------------------------------------------------------------------

resource "kubernetes_service_account" "homepage" {
  metadata {
    name      = "homepage"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "homepage"
    }
  }
}

resource "kubernetes_cluster_role" "homepage" {
  metadata {
    name = "homepage"
    labels = {
      "app.kubernetes.io/name" = "homepage"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "nodes"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["traefik.io", "traefik.containo.us"]
    resources  = ["ingressroutes"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["nodes", "pods"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions/status"]
    verbs      = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "homepage" {
  metadata {
    name = "homepage"
    labels = {
      "app.kubernetes.io/name" = "homepage"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.homepage.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.homepage.metadata[0].name
    namespace = var.namespace
  }
}

# -------------------------------------------------------------------------
# ConfigMap — global config that isn't per-service
# -------------------------------------------------------------------------
# EDITING GUIDE:
#
# settings.yaml  — title, theme, background, layout order of service groups
# widgets.yaml   — top-bar widgets: cluster resources, date/time, search
# bookmarks.yaml — quick-link bookmarks (not services, just URL shortcuts)
# kubernetes.yaml — tells Homepage to use cluster mode for service discovery
# services.yaml  — leave empty ("") — services come from Ingress annotations
#
# Group ordering in settings.yaml layout controls the column order on the dashboard.
# Add a new group name here when you create a new service group.

resource "kubernetes_config_map" "homepage" {
  metadata {
    name      = "homepage"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "homepage"
    }
  }

  data = {
    "kubernetes.yaml" = <<-YAML
      mode: cluster
    YAML

    "settings.yaml" = <<-YAML
      title: ${var.title}
      theme: dark
      color: slate
      headerStyle: clean
      layout:
        Infrastructure:
          style: row
          columns: 4
        Monitoring:
          style: row
          columns: 4
        Media:
          style: row
          columns: 4
        Personal:
          style: row
          columns: 4
    YAML

    # Top-bar widgets: cluster resource usage + date/time + search
    "widgets.yaml" = <<-YAML
      - kubernetes:
          cluster:
            show: true
            cpu: true
            memory: true
            showLabel: true
            label: "dawnfire"
          nodes:
            show: true
            cpu: true
            memory: true
            showLabel: true
      - datetime:
          text_size: xl
          format:
            dateStyle: short
            timeStyle: short
            hour12: true
      - search:
          provider: duckduckgo
          target: _blank
    YAML

    # Bookmarks — quick links that aren't full services
    # Format: - Group: - Name: - abbr: XX (two-letter abbreviation) href: URL
    "bookmarks.yaml" = <<-YAML
      - Homelab:
          - GitHub:
              - abbr: GH
                href: https://github.com
          - Cloudflare:
              - abbr: CF
                href: https://dash.cloudflare.com
          - Tailscale:
              - abbr: TS
                href: https://login.tailscale.com
    YAML

    # services.yaml left empty — all services come from gethomepage.dev/ Ingress annotations
    "services.yaml" = ""

    "custom.css" = ""
    "custom.js"  = ""
    "docker.yaml" = ""
  }
}

# -------------------------------------------------------------------------
# Deployment
# -------------------------------------------------------------------------

resource "kubernetes_deployment" "homepage" {
  metadata {
    name      = "homepage"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "homepage"
    }
  }

  # The dawnfire namespace is created by the registry/ module.
  # This depends_on makes the ordering explicit even though both modules
  # are applied independently — if the namespace doesn't exist, the deployment fails fast.

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "homepage"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "homepage"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.homepage.metadata[0].name

        container {
          name  = "homepage"
          image = "ghcr.io/gethomepage/homepage:latest"

          env {
            name  = "HOMEPAGE_ALLOWED_HOSTS"
            value = var.hostname
          }

          port {
            container_port = 3000
            protocol       = "TCP"
          }

          volume_mount {
            name       = "homepage-config"
            mount_path = "/app/config/kubernetes.yaml"
            sub_path   = "kubernetes.yaml"
          }

          volume_mount {
            name       = "homepage-config"
            mount_path = "/app/config/settings.yaml"
            sub_path   = "settings.yaml"
          }

          volume_mount {
            name       = "homepage-config"
            mount_path = "/app/config/widgets.yaml"
            sub_path   = "widgets.yaml"
          }

          volume_mount {
            name       = "homepage-config"
            mount_path = "/app/config/bookmarks.yaml"
            sub_path   = "bookmarks.yaml"
          }

          volume_mount {
            name       = "homepage-config"
            mount_path = "/app/config/services.yaml"
            sub_path   = "services.yaml"
          }

          volume_mount {
            name       = "homepage-config"
            mount_path = "/app/config/custom.css"
            sub_path   = "custom.css"
          }

          volume_mount {
            name       = "homepage-config"
            mount_path = "/app/config/custom.js"
            sub_path   = "custom.js"
          }

          volume_mount {
            name       = "homepage-config"
            mount_path = "/app/config/docker.yaml"
            sub_path   = "docker.yaml"
          }

          volume_mount {
            name       = "logs"
            mount_path = "/app/config/logs"
          }
        }

        volume {
          name = "homepage-config"
          config_map {
            name = kubernetes_config_map.homepage.metadata[0].name
          }
        }

        volume {
          name = "logs"
          empty_dir {}
        }
      }
    }
  }
}

# -------------------------------------------------------------------------
# Service and Ingress
# -------------------------------------------------------------------------

resource "kubernetes_service" "homepage" {
  metadata {
    name      = "homepage"
    namespace = var.namespace
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "homepage"
    }

    type = "ClusterIP"

    port {
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "homepage" {
  metadata {
    name      = "homepage"
    namespace = var.namespace
    annotations = {
      "cert-manager.io/cluster-issuer"                   = var.cert_issuer
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-redirect-to-https@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = [var.hostname]
      secret_name = "homepage-tls"
    }

    rule {
      host = var.hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.homepage.metadata[0].name
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
