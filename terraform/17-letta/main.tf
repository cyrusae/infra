# Letta — stateful AI agent server.
#
# Apply order: Layer 5, step 5. After homepage/ and registry/.
# Depends on the ollama/ module (Layer 5, step 4.5) if using local embeddings.
#
# Architecture:
#   - letta-db:   PostgreSQL 17 with pgvector extension (Deployment + ClusterIP + PVC)
#   - letta:      Letta server (Deployment + ClusterIP + Traefik Ingress)
#
# Why a separate PostgreSQL instead of the bundled one in letta/letta?
#   The all-in-one image bundles Postgres, Redis, Node.js, and an OTel collector.
#   That's convenient for `docker run` but wrong for Kubernetes — the DB lifecycle
#   must be independent of the app container. A pod restart should never risk DB
#   state. Using a separate Deployment means the app is stateless and the DB
#   handles persistence correctly.
#
# Secrets passed via environment variables:
#   export TF_VAR_server_password="..."
#   export TF_VAR_db_password="..."
#   export TF_VAR_anthropic_api_key="..."   # optional
#   export TF_VAR_openai_api_key="..."      # optional
#
# Letta moves fast. Before applying, check the latest image tag at:
#   https://hub.docker.com/r/letta/letta/tags
# Pin to a specific version in var.letta_image for production stability.

locals {
  # Provider env vars: only include entries where a key/URL is set.
  # Letta tries to contact every configured provider on startup — empty keys cause errors.
  optional_provider_envs = concat(
    var.openai_api_key != "" ? [
      { name = "OPENAI_API_KEY", value = var.openai_api_key, secret = true }
    ] : [],
    var.anthropic_api_key != "" ? [
      { name = "ANTHROPIC_API_KEY", value = var.anthropic_api_key, secret = true }
    ] : [],
    var.ollama_base_url != "" ? [
      { name = "OLLAMA_BASE_URL", value = var.ollama_base_url, secret = false }
    ] : [],
  )
}

# -------------------------------------------------------------------------
# Namespace
# -------------------------------------------------------------------------

resource "kubernetes_namespace" "letta" {
  metadata {
    name = var.namespace
  }
}

# -------------------------------------------------------------------------
# Secrets
# -------------------------------------------------------------------------

resource "kubernetes_secret" "letta" {
  metadata {
    name      = "letta-secrets"
    namespace = kubernetes_namespace.letta.metadata[0].name
  }

  data = {
    server-password   = var.server_password
    db-password       = var.db_password
    openai-api-key    = var.openai_api_key
    anthropic-api-key = var.anthropic_api_key
  }

  type = "Opaque"
}

# -------------------------------------------------------------------------
# PostgreSQL + pgvector
#
# pgvector/pgvector:pg17 is the official pgvector image — it ships with
# the extension pre-compiled. The extension still needs to be enabled via
# CREATE EXTENSION, which we do via the /docker-entrypoint-initdb.d/ hook.
# This init script only runs on the very first start (empty data directory).
# -------------------------------------------------------------------------

resource "kubernetes_config_map" "letta_db_init" {
  metadata {
    name      = "letta-db-init"
    namespace = kubernetes_namespace.letta.metadata[0].name
  }

  data = {
    "01-init.sql" = <<-SQL
      CREATE EXTENSION IF NOT EXISTS vector;
      CREATE EXTENSION IF NOT EXISTS pg_trgm;
    SQL
  }
}

resource "kubernetes_persistent_volume_claim" "letta_db" {
  metadata {
    name      = "letta-db"
    namespace = kubernetes_namespace.letta.metadata[0].name
    annotations = {
      "dawnfire.casa/backup-priority" = "high"
      "dawnfire.casa/note"            = "Agent memory, archival passages, and conversation history"
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

resource "kubernetes_deployment" "letta_db" {
  metadata {
    name      = "letta-db"
    namespace = kubernetes_namespace.letta.metadata[0].name
    labels = {
      app = "letta-db"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "letta-db"
      }
    }

    template {
      metadata {
        labels = {
          app = "letta-db"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "pgvector/pgvector:pg17"

          env {
            name  = "POSTGRES_DB"
            value = "letta"
          }

          env {
            name  = "POSTGRES_USER"
            value = "letta"
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.letta.metadata[0].name
                key  = "db-password"
              }
            }
          }

          # Tune shared_buffers and work_mem for a small homelab DB.
          # pgvector index scans benefit from higher work_mem.
          env {
            name  = "POSTGRES_INITDB_ARGS"
            value = "--encoding=UTF-8 --locale=C"
          }

          port {
            container_port = 5432
            protocol       = "TCP"
          }

          volume_mount {
            name       = "db-data"
            mount_path = "/var/lib/postgresql/data"
            sub_path   = "postgres" # avoids lost+found issue on ext4 volumes
          }

          volume_mount {
            name       = "db-init"
            mount_path = "/docker-entrypoint-initdb.d"
            read_only  = true
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "letta"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            failure_threshold     = 6
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "letta"]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "1Gi"
            }
          }
        }

        volume {
          name = "db-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.letta_db.metadata[0].name
          }
        }

        volume {
          name = "db-init"
          config_map {
            name = kubernetes_config_map.letta_db_init.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "letta_db" {
  metadata {
    name      = "letta-db"
    namespace = kubernetes_namespace.letta.metadata[0].name
  }

  spec {
    selector = {
      app = "letta-db"
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
# Letta server
#
# No PVC — the app is stateless when backed by external PostgreSQL.
# All agent state lives in the DB. Pod restarts are safe.
#
# FIRST BOOT NOTE: Letta runs Alembic migrations on startup (150+ migrations
# against PostgreSQL). Expect 60–120 seconds before the API is ready.
# The readiness probe accounts for this via initial_delay_seconds.
# -------------------------------------------------------------------------

resource "kubernetes_deployment" "letta" {
  metadata {
    name      = "letta"
    namespace = kubernetes_namespace.letta.metadata[0].name
    labels = {
      app = "letta"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "letta"
      }
    }

    template {
      metadata {
        labels = {
          app = "letta"
        }
      }

      spec {
        # Wait for DB to be healthy before starting Letta.
        # Without this, Letta will fail fast on startup if DB isn't ready yet.
        init_container {
          name    = "wait-for-db"
          image   = "busybox:1.36"
          command = ["sh", "-c", "until nc -z letta-db 5432; do echo 'waiting for postgres'; sleep 2; done"]
        }

        container {
          name  = "letta"
          image = var.letta_image

          # Database connection — individual vars so we can use a k8s secret
          # for the password without having to construct a URI string in Terraform.
          env {
            name  = "LETTA_PG_HOST"
            value = kubernetes_service.letta_db.metadata[0].name
          }

          env {
            name  = "LETTA_PG_PORT"
            value = "5432"
          }

          env {
            name  = "LETTA_PG_USER"
            value = "letta"
          }

          env {
            name  = "LETTA_PG_DB"
            value = "letta"
          }

          env {
            name = "LETTA_PG_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.letta.metadata[0].name
                key  = "db-password"
              }
            }
          }

          # Connection pool — 20/worker is conservative; raise if you see
          # "connection pool exhausted" in logs under concurrent agent calls.
          env {
            name  = "LETTA_PG_POOL_SIZE"
            value = tostring(var.db_pool_size)
          }

          env {
            name  = "LETTA_PG_MAX_OVERFLOW"
            value = "10"
          }

          # Server authentication
          env {
            name  = "SECURE"
            value = "true"
          }

          env {
            name = "LETTA_SERVER_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.letta.metadata[0].name
                key  = "server-password"
              }
            }
          }

          # Worker count — increase only if you see latency under concurrent load.
          # Each additional worker multiplies DB pool connections.
          env {
            name  = "LETTA_UVICORN_WORKERS"
            value = tostring(var.uvicorn_workers)
          }

          env {
            name  = "LETTA_ENVIRONMENT"
            value = "PRODUCTION"
          }

          # Optional provider API keys — only injected if set
          dynamic "env" {
            for_each = var.openai_api_key != "" ? [1] : []
            content {
              name = "OPENAI_API_KEY"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret.letta.metadata[0].name
                  key  = "openai-api-key"
                }
              }
            }
          }

          dynamic "env" {
            for_each = var.anthropic_api_key != "" ? [1] : []
            content {
              name = "ANTHROPIC_API_KEY"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret.letta.metadata[0].name
                  key  = "anthropic-api-key"
                }
              }
            }
          }

          dynamic "env" {
            for_each = var.ollama_base_url != "" ? [1] : []
            content {
              name  = "OLLAMA_BASE_URL"
              value = var.ollama_base_url
            }
          }

          port {
            name           = "api"
            container_port = 8283
            protocol       = "TCP"
          }

          # Letta runs Alembic migrations on first boot — give it time.
          readiness_probe {
            http_get {
              path = "/v1/health"
              port = 8283
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            failure_threshold     = 12 # 2 minutes of retries
          }

          liveness_probe {
            http_get {
              path = "/v1/health"
              port = 8283
            }
            initial_delay_seconds = 120
            period_seconds        = 30
            failure_threshold     = 3
          }

          resources {
            requests = {
              memory = "512Mi"
              cpu    = "200m"
            }
            limits = {
              memory = "2Gi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment.letta_db,
    kubernetes_service.letta_db,
  ]
}

resource "kubernetes_service" "letta" {
  metadata {
    name      = "letta"
    namespace = kubernetes_namespace.letta.metadata[0].name
    annotations = {
      # Homepage service discovery
      "gethomepage.dev/enabled"     = "true"
      "gethomepage.dev/name"        = "Letta"
      "gethomepage.dev/description" = "Stateful AI agent server"
      "gethomepage.dev/group"       = "AI"
      "gethomepage.dev/icon"        = "https://avatars.githubusercontent.com/u/132110378"
    }
  }

  spec {
    selector = {
      app = "letta"
    }

    type = "ClusterIP"

    port {
      name        = "api"
      port        = 8283
      target_port = 8283
      protocol    = "TCP"
    }
  }
}

# -------------------------------------------------------------------------
# Traefik Ingress
# -------------------------------------------------------------------------

resource "kubernetes_ingress_v1" "letta" {
  metadata {
    name      = "letta"
    namespace = kubernetes_namespace.letta.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "cert-manager.io/cluster-issuer"                   = var.cert_issuer
      # Letta API responses can be large (streaming agent output).
      # Raise the body buffer limit to avoid truncated responses.
      "traefik.ingress.kubernetes.io/router.middlewares" = ""
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = [var.hostname]
      secret_name = "letta-tls"
    }

    rule {
      host = var.hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.letta.metadata[0].name
              port {
                number = 8283
              }
            }
          }
        }
      }
    }
  }
}
