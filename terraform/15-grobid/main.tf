
# Namespace
resource "kubernetes_namespace_v1" "grobid" {
  metadata {
    name = var.grobid_namespace
    labels = {
      "app.kubernetes.io/name"       = "grobid"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# PVC for GROBID working directory and model cache
resource "kubernetes_persistent_volume_claim_v1" "grobid" {
  metadata {
    name      = "grobid-data"
    namespace = kubernetes_namespace_v1.grobid.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "longhorn"
    resources {
      requests = {
        storage = var.grobid_storage_size
      }
    }
  }
}

# ConfigMap for GROBID production configuration
# See: https://grobid.readthedocs.io/en/latest/Grobid-service/
resource "kubernetes_config_map_v1" "grobid" {
  metadata {
    name      = "grobid-config"
    namespace = kubernetes_namespace.grobid.metadata[0].name
  }

  data = {
    # GROBID configuration YAML (mounted as /opt/grobid/grobid-home/config/grobid.yaml)
    "grobid.yaml" = <<-EOF
      # Production configuration for GROBID service
      # Tuned for persistent deployment with GPU acceleration

      server:
        port: 8070
        host: "0.0.0.0"

      # CRF models configuration
      models:
        # Keep default CRF cascade
        segmentation:
          architecture: "BidLSTM-CRF"
        reference-segmenter:
          architecture: "BidLSTM-CRF-FEATURES"
        citation:
          architecture: "BidLSTM-CRF-FEATURES"

      # Deep Learning models (via DeLFT, requires GPU or CPU fallback)
      deepLearning:
        # Use DL models for header, citations, and fulltext
        models:
          # Header parsing (significant accuracy gain with DL)
          - header
          # Reference/citation extraction (DL provides +2-4 F1-score vs CRF)
          - citations
        # GPU auto-detection on Linux; disable if needed
        useGPU: true

      # Threading and parallelism
      service:
        # Worker threads for PDF processing
        # Conservative (4) avoids contention with GPU time-slicing
        # Increase cautiously if CPU is bottleneck
        nthreads: ${var.grobid_worker_threads}
        # Max concurrent requests before returning 503 (backpressure)
        max_parallel_requests: ${var.grobid_max_concurrent_requests}

      # Memory and resource tuning
      # TensorFlow memory growth is controlled via TF_FORCE_GPU_ALLOW_GROWTH env var
      #
      # PDF processing temporary files
      temp:
        path: "/tmp/grobid"
        max_disk_size: "50Gi"
    EOF
  }
}

# StatefulSet for persistent GROBID deployment
resource "kubernetes_stateful_set_v1" "grobid" {
  metadata {
    name      = "grobid"
    namespace = kubernetes_namespace_v1.grobid.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "grobid"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    service_name = kubernetes_service_v1.grobid_headless.metadata[0].name
    replicas     = var.grobid_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "grobid"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "grobid"
        }
      }

      spec {
        # Node affinity: run only on GPU-enabled Babbage
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "gpu"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }
          }
        }

        # Container specification
        container {
          name  = "grobid"
          image = "grobid/grobid:${var.grobid_version}"
          # Always use official grobid/grobid repo, not lfoppiano/grobid
          # (breaking change in 0.8.2: lfoppiano/grobid tag conventions changed)

          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8070
            protocol       = "TCP"
          }

          # Resource requests/limits
          resources {
            requests = {
              # GPU time-slice (1 of 8 available on Babbage)
              "nvidia.com/gpu" = "1"
              # CPU request (conservative; increase if queue backs up)
              cpu    = "1000m"
              memory = "3Gi"  # DL models + Java runtime
            }
            limits = {
              "nvidia.com/gpu" = "1"
              cpu              = "3000m"
              memory           = "6Gi"  # Prevent OOM during large document processing
            }
          }

          # Environment variables
          env {
            name  = "TF_FORCE_GPU_ALLOW_GROWTH"
            value = "true"
            # Critical: prevents TensorFlow from pre-allocating entire 8GB VRAM.
            # With time-slicing (8 shares on GTX 1070), this allows multiple
            # workloads (Ollama, GROBID, etc.) to coexist without OOM.
          }

          env {
            name  = "JAVA_OPTS"
            value = "-Xmx4g"
            # Java heap size for PDF processing
          }

          env {
            name  = "GROBID_HOME"
            value = "/opt/grobid/grobid-home"
          }

          # Configuration volume mount
          volume_mount {
            name       = "config"
            mount_path = "/opt/grobid/grobid-home/config"
            read_only  = false
          }

          # Persistent storage for working directory and model cache
          volume_mount {
            name       = "data"
            mount_path = "/opt/grobid/data"
          }

          # Health checks
          startup_probe {
            http_get {
              path   = "/api/isalive"
              port   = "http"
              scheme = "HTTP"
            }
            failure_threshold = 30
            period_seconds    = 10
            # 5 minute startup window (models + embeddings take time to load)
          }

          liveness_probe {
            http_get {
              path   = "/api/isalive"
              port   = "http"
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/api/isalive"
              port   = "http"
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            failure_threshold     = 2
          }

          # Mount the runtime class for GPU support
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
          }
        }

        # Use nvidia runtime for GPU access
        runtime_class_name = "nvidia"

        # Volume definitions
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.grobid.metadata[0].name
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.grobid.metadata[0].name
          }
        }

        # Pod disruption budget (prevent eviction of the single instance)
        termination_grace_period_seconds = 60
      }
    }

    # Persistent volume claim templates (none; using pre-created PVC)
    # For future scaling: switch to volumeClaimTemplates if needed
  }
}

# Headless service (for StatefulSet DNS stability)
resource "kubernetes_service_v1" "grobid_headless" {
  metadata {
    name      = "grobid-headless"
    namespace = kubernetes_namespace_v1.grobid.metadata[0].name
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "grobid"
    }

    port {
      name       = "http"
      port       = 8070
      target_port = 8070
      protocol   = "TCP"
    }

    cluster_ip = "None"  # Headless
  }
}

# LoadBalancer service (for direct access, if needed)
resource "kubernetes_service_v1" "grobid_lb" {
  metadata {
    name      = "grobid-lb"
    namespace = kubernetes_namespace_v1.grobid.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "grobid"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "grobid"
    }

    type = "LoadBalancer"

    port {
      name       = "http"
      port       = 8070
      target_port = "http"
      protocol   = "TCP"
    }
  }
}

# Ingress for web UI access via domain
resource "kubernetes_ingress_v1" "grobid" {
  metadata {
    name      = "grobid"
    namespace = kubernetes_namespace_v1.grobid.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web,websecure"
    }
  }

  spec {
    tls {
      hosts       = ["grobid.${var.domain}"]
      secret_name = "grobid-tls"
    }

    rule {
      host = "grobid.${var.domain}"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.grobid_lb.metadata[0].name
              port {
                number = 8070
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.grobid_lb,
  ]
}
