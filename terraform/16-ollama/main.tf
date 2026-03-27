# Ollama — local LLM inference server.
#
# Apply order: Layer 5, step 4.5. After core services, before letta/.
# The letta/ module's ollama_base_url variable points here by default.
#
# GPU pinning:
#   Ollama is pinned to Babbage via nodeAffinity (var.gpu_node_hostname).
#   The nvidia-gpu/ module must be applied first — it registers the
#   NVIDIA RuntimeClass and device plugin DaemonSet that this pod depends on.
#   Without it, the GPU resource request will be unsatisfiable and the pod
#   will stay Pending indefinitely.
#
# Model management:
#   Models are NOT pulled automatically by Terraform — Kubernetes has no
#   native mechanism for exec-ing post-deploy commands. Pull models manually
#   after first apply. See the README for the pull procedure.
#   Models persist in the PVC across pod restarts.
#
# Embedding recommendation for Letta:
#   nomic-embed-text — 274MB, 768 dims, runs well on GTX 1080
#   Pull after deploy: kubectl exec -n ollama deploy/ollama -- ollama pull nomic-embed-text
#
# For chat models on a GTX 1080 (8GB VRAM):
#   mistral:7b-instruct     — 4.1GB, fits in VRAM
#   llama3.1:8b             — 4.7GB, fits in VRAM
#   deepseek-r1:7b          — 4.7GB, fits in VRAM
#   phi3:mini               — 2.2GB, fast, good for tool use
#   llama3.1:70b-instruct-q2_K — ~25GB, CPU-only on this hardware (slow)
#
# The GTX 1080 has 8GB VRAM. Models larger than ~7GB will partially or fully
# offload to CPU/RAM. nomic-embed-text and the 7B class models fit entirely
# in VRAM and are the practical ceiling for this hardware with fast inference.

# -------------------------------------------------------------------------
# Namespace
# -------------------------------------------------------------------------

resource "kubernetes_namespace" "ollama" {
  metadata {
    name = var.namespace
  }
}

# -------------------------------------------------------------------------
# Persistent storage for model weights
# -------------------------------------------------------------------------

resource "kubernetes_persistent_volume_claim" "ollama_models" {
  metadata {
    name      = "ollama-models"
    namespace = kubernetes_namespace.ollama.metadata[0].name
    annotations = {
      "dawnfire.casa/backup-priority" = "low"
      "dawnfire.casa/note"            = "Model weights — re-pullable, not original data"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.model_storage_class

    resources {
      requests = {
        storage = var.model_storage_size
      }
    }
  }
}

# -------------------------------------------------------------------------
# Ollama Deployment
# -------------------------------------------------------------------------

resource "kubernetes_deployment" "ollama" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace.ollama.metadata[0].name
    labels = {
      app = "ollama"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "ollama"
      }
    }

    template {
      metadata {
        labels = {
          app = "ollama"
        }
      }

      spec {
        # Pin to the GPU node.
        # Ollama falls back to CPU if it can't find a GPU, which is very slow.
        # Hard affinity here is intentional — a silently CPU-bound Ollama would
        # appear to work but produce terrible inference latency.
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "kubernetes.io/hostname"
                  operator = "In"
                  values   = [var.gpu_node_hostname]
                }
              }
            }
          }
        }

        # Use the NVIDIA RuntimeClass registered by the nvidia-gpu/ module.
        # Without this, the container runtime won't pass GPU devices to the container.
        runtime_class_name = "nvidia"

        container {
          name  = "ollama"
          image = var.ollama_image

          port {
            name           = "api"
            container_port = 11434
            protocol       = "TCP"
          }

          # Request 1 GPU slice. The nvidia-gpu/ module configures 8 time-slices
          # on the GTX 1080, so this allows up to 8 concurrent GPU-using pods.
          # In practice Ollama is the primary GPU consumer — this is mostly
          # to ensure the device gets discovered and passed through.
          resources {
            requests = {
              memory           = "2Gi"
              cpu              = "500m"
              "nvidia.com/gpu" = "1"
            }
            limits = {
              memory           = "12Gi" # Headroom for large model CPU offload
              "nvidia.com/gpu" = "1"
            }
          }

          volume_mount {
            name       = "models"
            mount_path = "/root/.ollama"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 11434
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 11434
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }

        volume {
          name = "models"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.ollama_models.metadata[0].name
          }
        }
      }
    }
  }
}

# -------------------------------------------------------------------------
# ClusterIP Service
# Internal access: http://ollama.ollama.svc.cluster.local:11434
# This is the URL to set in the letta/ module's ollama_base_url variable.
# -------------------------------------------------------------------------

resource "kubernetes_service" "ollama" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace.ollama.metadata[0].name
    annotations = {
      "gethomepage.dev/enabled"     = "true"
      "gethomepage.dev/name"        = "Ollama"
      "gethomepage.dev/description" = "Local LLM inference (GTX 1080)"
      "gethomepage.dev/group"       = "AI"
      "gethomepage.dev/icon"        = "ollama"
    }
  }

  spec {
    selector = {
      app = "ollama"
    }

    type = "ClusterIP"

    port {
      name        = "api"
      port        = 11434
      target_port = 11434
      protocol    = "TCP"
    }
  }
}

# -------------------------------------------------------------------------
# Optional Traefik Ingress
#
# Expose Ollama externally to:
#   - Use the Letta ADE (app.letta.com) pointed at your self-hosted server
#   - Access models from Astraeus / Gaius without going through kubectl port-forward
#   - Connect other tools (Open WebUI, Continue.dev, etc.)
#
# Security note: Ollama has no built-in auth. The Ingress exposes the full
# model management API (including pull/delete). Consider adding a Traefik
# BasicAuth middleware before enabling this in production.
# For now, LAN + Tailscale access is sufficient.
# -------------------------------------------------------------------------

resource "kubernetes_ingress_v1" "ollama" {
  count = var.expose_ingress ? 1 : 0

  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace.ollama.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "cert-manager.io/cluster-issuer"                   = var.cert_issuer
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = [var.hostname]
      secret_name = "ollama-tls"
    }

    rule {
      host = var.hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.ollama.metadata[0].name
              port {
                number = 11434
              }
            }
          }
        }
      }
    }
  }
}
