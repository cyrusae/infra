# Nextcloud — self-hosted cloud storage, calendar (CalDAV), and contacts.
#
# Apply order: Layer 5, step 4. After homepage/.
#
# This module manages the full Nextcloud stack:
#   - PostgreSQL database
#   - Nextcloud application pod
#   - Background cron job (required for calendar sync and housekeeping)
#   - Traefik Ingress with TLS
#   - Cloudflare tunnel is managed separately (external access only)
#
# FIRST DEPLOY vs RESTORE:
#   First deploy:  terraform apply — Nextcloud initializes a fresh database
#   Restore:       Set restore_from_backup = true, restore PVC data manually,
#                  then terraform apply. See README for restore procedure.
#
# Storage tier: longhorn-critical (3 replicas) for both data and database.
# Nextcloud and Martin's calendar data are the most important data in the cluster.

# -------------------------------------------------------------------------
# Namespace
# -------------------------------------------------------------------------

resource "kubernetes_namespace" "nextcloud" {
  metadata {
    name = var.namespace
  }
}

# -------------------------------------------------------------------------
# Secrets
# -------------------------------------------------------------------------

resource "kubernetes_secret" "nextcloud" {
  metadata {
    name      = "nextcloud-secrets"
    namespace = kubernetes_namespace.nextcloud.metadata[0].name
  }

  data = {
    nextcloud-admin-password = var.nextcloud_admin_password
    db-password              = var.db_password
    db-root-password         = var.db_root_password
  }

  type = "Opaque"
}

# -------------------------------------------------------------------------
# Persistent storage
# -------------------------------------------------------------------------

resource "kubernetes_persistent_volume_claim" "nextcloud_data" {
  metadata {
    name      = "nextcloud-data"
    namespace = kubernetes_namespace.nextcloud.metadata[0].name
    annotations = {
      # Document that this PVC contains critical user data
      "dawnfire.casa/backup-priority" = "critical"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.data_storage_class

    resources {
      requests = {
        storage = var.data_storage_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "nextcloud_db" {
  metadata {
    name      = "nextcloud-db"
    namespace = kubernetes_namespace.nextcloud.metadata[0].name
    annotations = {
      "dawnfire.casa/backup-priority" = "critical"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.db_storage_class

    resources {
      requests = {
        storage = var.db_storage_size
      }
    }
  }
}

# -------------------------------------------------------------------------
# PostgreSQL
# -------------------------------------------------------------------------

resource "kubernetes_deployment" "nextcloud_db" {
  metadata {
    name      = "nextcloud-db"
    namespace = kubernetes_namespace.nextcloud.metadata[0].name
    labels = {
      app = "nextcloud-db"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nextcloud-db"
      }
    }

    template {
      metadata {
        labels = {
          app = "nextcloud-db"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:16-alpine"

          env {
            name  = "POSTGRES_DB"
            value = "nextcloud"
          }

          env {
            name  = "POSTGRES_USER"
            value = "nextcloud"
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.nextcloud.metadata[0].name
                key  = "db-password"
              }
            }
          }

          env {
            name = "POSTGRES_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.nextcloud.metadata[0].name
                key  = "db-root-password"
              }
            }
          }

          port {
            container_port = 5432
            protocol       = "TCP"
          }

          volume_mount {
            name       = "db-data"
            mount_path = "/var/lib/postgresql/data"
            sub_path   = "postgres" # avoids lost+found issue on ext4
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "nextcloud"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }
        }

        volume {
          name = "db-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.nextcloud_db.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nextcloud_db" {
  metadata {
    name      = "nextcloud-db"
    namespace = kubernetes_namespace.nextcloud.metadata[0].name
  }

  spec {
    selector = {
      app = "nextcloud-db"
    }

    type = "ClusterIP"

    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }
  }
}

# -------------------------------------------------------------------------
# Nextcloud application
# -------------------------------------------------------------------------

resource "kubernetes_deployment" "nextcloud" {
  metadata {
    name      = "nextcloud"
    namespace = kubernetes_namespace.nextcloud.metadata[0].name
    labels = {
      app = "nextcloud"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nextcloud"
      }
    }

    template {
      metadata {
        labels = {
          app = "nextcloud"
        }
      }

      spec {
        container {
          name  = "nextcloud"
          image = "nextcloud:28-apache"

          env {
            name  = "NEXTCLOUD_TRUSTED_DOMAINS"
            value = "${var.hostname} nextcloud.nextcloud.svc.cluster.local"
          }

          env {
            name  = "NEXTCLOUD_ADMIN_USER"
            value = "admin"
          }

          env {
            name = "NEXTCLOUD_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.nextcloud.metadata[0].name
                key  = "nextcloud-admin-password"
              }
            }
          }

          # PostgreSQL connection
          env {
            name  = "POSTGRES_HOST"
            value = kubernetes_service.nextcloud_db.metadata[0].name
          }

          env {
            name  = "POSTGRES_DB"
            value = "nextcloud"
          }

          env {
            name  = "POSTGRES_USER"
            value = "nextcloud"
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.nextcloud.metadata[0].name
                key  = "db-password"
              }
            }
          }

          # Required for Traefik reverse proxy — tells Nextcloud to trust the proxy headers
          env {
            name  = "NEXTCLOUD_TRUSTED_PROXIES"
            value = "10.0.0.0/8"
          }

          env {
            name  = "OVERWRITEPROTOCOL"
            value = "https"
          }

          env {
            name  = "OVERWRITECLIURL"
            value = "https://${var.hostname}"
          }

          port {
            container_port = 80
            protocol       = "TCP"
          }

          volume_mount {
            name       = "nextcloud-data"
            mount_path = "/var/www/html"
          }

          # Nextcloud can be slow to start on first boot (initializes DB schema)
          liveness_probe {
            http_get {
              path = "/status.php"
              port = 80
            }
            initial_delay_seconds = 120
            period_seconds        = 30
            failure_threshold     = 6
          }

          readiness_probe {
            http_get {
              path = "/status.php"
              port = 80
            }
            initial_delay_seconds = 60
            period_seconds        = 15
          }
        }

        volume {
          name = "nextcloud-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.nextcloud_data.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.nextcloud_db]
}

# -------------------------------------------------------------------------
# Background cron job
# -------------------------------------------------------------------------
# Required for calendar sync, file cleanup, and other Nextcloud housekeeping.
# Without this, CalDAV sync becomes unreliable within hours.

resource "kubernetes_cron_job_v1" "nextcloud_cron" {
  metadata {
    name      = "nextcloud-cron"
    namespace = kubernetes_namespace.nextcloud.metadata[0].name
  }

  spec {
    schedule                      = "*/5 * * * *"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {}

      spec {
        template {
          metadata {}

          spec {
            restart_policy = "OnFailure"

            container {
              name  = "nextcloud-cron"
              image = "nextcloud:28-apache"

              command = ["php", "-f", "/var/www/html/cron.php"]

              volume_mount {
                name       = "nextcloud-data"
                mount_path = "/var/www/html"
              }
            }

            volume {
              name = "nextcloud-data"
              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim.nextcloud_data.metadata[0].name
              }
            }
          }
        }
      }
    }
  }
}

# -------------------------------------------------------------------------
# Service and Ingress
# -------------------------------------------------------------------------

resource "kubernetes_service" "nextcloud" {
  metadata {
    name      = "nextcloud"
    namespace = kubernetes_namespace.nextcloud.metadata[0].name
  }

  spec {
    selector = {
      app = "nextcloud"
    }

    type = "ClusterIP"

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "nextcloud" {
  metadata {
    name      = "nextcloud"
    namespace = kubernetes_namespace.nextcloud.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                   = var.cert_issuer
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-redirect-to-https@kubernetescrd"
      # Nextcloud uploads can be large — raise the body size limit
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      # Homepage service discovery
      "gethomepage.dev/enabled"     = "true"
      "gethomepage.dev/name"        = "Nextcloud"
      "gethomepage.dev/description" = "Files, calendar, and contacts"
      "gethomepage.dev/group"       = "Personal"
      "gethomepage.dev/icon"        = "nextcloud.png"
      "gethomepage.dev/href"        = "https://${var.hostname}"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = [var.hostname]
      secret_name = "nextcloud-tls"
    }

    rule {
      host = var.hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.nextcloud.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
