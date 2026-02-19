# Pi-hole — network-wide DNS and ad blocking.
#
# Apply order: Layer 5, step 1. After all Layer 3 and Layer 4 modules.
#
# Architecture (corrected from pre-rebuild):
#   - LoadBalancer service: port 53 only (DNS). IP: 192.168.4.241.
#   - Web UI: via Traefik Ingress at pihole.dawnfire.casa. No host ports 80/443.
#   - This eliminates the port conflict with Traefik that broke the old cluster.
#
# After apply:
#   1. Verify pod is running and DNS is serving on 192.168.4.241:53
#   2. Switch Eero primary DNS to 192.168.4.241 (secondary: 1.1.1.1)
#   3. Verify *.dawnfire.casa resolves correctly from client devices
#
# HA model: single pod + Longhorn storage + MetalLB IP stability.
#   MetalLB failover: ~5-10s, K8s reschedule: ~20-30s, Longhorn: survives node loss.
#   Brief DNS downtime during failover is acceptable; devices fall back to secondary DNS.

# -------------------------------------------------------------------------
# Namespace
# -------------------------------------------------------------------------

resource "kubernetes_namespace" "pihole" {
  metadata {
    name = var.namespace
  }
}

# -------------------------------------------------------------------------
# Secrets
# -------------------------------------------------------------------------

resource "kubernetes_secret" "pihole_password" {
  metadata {
    name      = "pihole-password"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  data = {
    password = var.pihole_password
  }

  type = "Opaque"
}

# -------------------------------------------------------------------------
# Custom DNS ConfigMap
# -------------------------------------------------------------------------
# Pi-hole resolves *.dawnfire.casa to Traefik's LoadBalancer IP.
# This is what makes internal service URLs work when Pi-hole is your DNS server.

resource "kubernetes_config_map" "pihole_custom_dns" {
  metadata {
    name      = "pihole-custom-dns"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  data = {
    # Wildcard entry: all *.dawnfire.casa subdomains resolve to Traefik
    "02-custom.conf" = "address=/.dawnfire.casa/${var.traefik_ip}\n"
  }
}

# -------------------------------------------------------------------------
# Persistent storage
# -------------------------------------------------------------------------

resource "kubernetes_persistent_volume_claim" "pihole_config" {
  metadata {
    name      = "pihole-config"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.config_storage_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "pihole_dnsmasq" {
  metadata {
    name      = "pihole-dnsmasq"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.dnsmasq_storage_size
      }
    }
  }
}

# -------------------------------------------------------------------------
# Deployment
# -------------------------------------------------------------------------

resource "kubernetes_deployment" "pihole" {
  metadata {
    name      = "pihole"
    namespace = kubernetes_namespace.pihole.metadata[0].name
    labels = {
      app = "pihole"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "pihole"
      }
    }

    template {
      metadata {
        labels = {
          app = "pihole"
        }
      }

      spec {
        container {
          name  = "pihole"
          image = "pihole/pihole:latest"

          env {
            name  = "TZ"
            value = var.timezone
          }

          env {
            name  = "PIHOLE_DNS_"
            value = "${var.upstream_dns_1};${var.upstream_dns_2}"
          }

          env {
            name = "WEBPASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.pihole_password.metadata[0].name
                key  = "password"
              }
            }
          }

          # Web UI port — accessed via Traefik Ingress, not exposed directly
          port {
            name           = "web"
            container_port = 80
            protocol       = "TCP"
          }

          # DNS ports
          port {
            name           = "dns-tcp"
            container_port = 53
            protocol       = "TCP"
          }

          port {
            name           = "dns-udp"
            container_port = 53
            protocol       = "UDP"
          }

          volume_mount {
            name       = "pihole-config"
            mount_path = "/etc/pihole"
          }

          volume_mount {
            name       = "pihole-dnsmasq"
            mount_path = "/etc/dnsmasq.d"
          }

          volume_mount {
            name       = "pihole-custom-dns"
            mount_path = "/etc/dnsmasq.d/02-custom.conf"
            sub_path   = "02-custom.conf"
            read_only  = true
          }
        }

        volume {
          name = "pihole-config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.pihole_config.metadata[0].name
          }
        }

        volume {
          name = "pihole-dnsmasq"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.pihole_dnsmasq.metadata[0].name
          }
        }

        volume {
          name = "pihole-custom-dns"
          config_map {
            name = kubernetes_config_map.pihole_custom_dns.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_persistent_volume_claim.pihole_config,
    kubernetes_persistent_volume_claim.pihole_dnsmasq,
  ]
}

# -------------------------------------------------------------------------
# Services
# -------------------------------------------------------------------------

# DNS service — LoadBalancer on port 53 only.
# This is the only LoadBalancer Pi-hole gets. No ports 80 or 443 here.
resource "kubernetes_service" "pihole_dns" {
  metadata {
    name      = "pihole-dns"
    namespace = kubernetes_namespace.pihole.metadata[0].name
    annotations = {
      "metallb.universe.tf/loadBalancerIPs" = var.load_balancer_ip
    }
  }

  spec {
    selector = {
      app = "pihole"
    }

    type                    = "LoadBalancer"
    external_traffic_policy = "Cluster"

    port {
      name        = "dns-tcp"
      port        = 53
      target_port = 53
      protocol    = "TCP"
    }

    port {
      name        = "dns-udp"
      port        = 53
      target_port = 53
      protocol    = "UDP"
    }
  }
}

# Web UI service — ClusterIP only, accessed through Traefik Ingress.
resource "kubernetes_service" "pihole_web" {
  metadata {
    name      = "pihole-web"
    namespace = kubernetes_namespace.pihole.metadata[0].name
  }

  spec {
    selector = {
      app = "pihole"
    }

    type = "ClusterIP"

    port {
      name        = "web"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}

# -------------------------------------------------------------------------
# Ingress — web UI via Traefik
# -------------------------------------------------------------------------

resource "kubernetes_ingress_v1" "pihole_web" {
  metadata {
    name      = "pihole-web"
    namespace = kubernetes_namespace.pihole.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                    = var.cert_issuer
      "traefik.ingress.kubernetes.io/router.middlewares"  = "traefik-redirect-to-https@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = ["pihole.dawnfire.casa"]
      secret_name = "pihole-tls"
    }

    rule {
      host = "pihole.dawnfire.casa"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.pihole_web.metadata[0].name
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
