# Traefik — ingress controller and reverse proxy for all *.dawnfire.casa services.
#
# Apply order: Layer 3, step 5 (last). After cert-manager/.
# All application services depend on Traefik existing before their Ingress resources work.
#
# Architecture note: Traefik runs as a standard Deployment (not DaemonSet/hostNetwork).
# MetalLB assigns it a stable LoadBalancer IP (192.168.4.240). Pi-hole gets its own
# separate LoadBalancer IP (192.168.4.241) for DNS — there is no port conflict.
# This is the fix for the port 80/443 conflict that plagued the pre-rebuild cluster.
#
# K3s ships with its own Traefik instance. We disable the K3s built-in and manage
# Traefik ourselves so we control the version and configuration.
# Disable K3s Traefik by adding to /etc/rancher/k3s/config.yaml (Ansible layer2-k3s):
#   disable:
#     - traefik

resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  wait    = true
  timeout = 300

  # Stable LoadBalancer IP — must match what Pi-hole's custom DNS points to.
  set {
    name  = "service.spec.loadBalancerIP"
    value = var.load_balancer_ip
  }

  # Use MetalLB LoadBalancer, not K3s hostNetwork/svclb.
  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  # Enable the dashboard (accessible via IngressRoute, not exposed publicly).
  set {
    name  = "api.dashboard"
    value = "true"
  }

  # Entrypoints: web (80) and websecure (443).
  # web redirects to websecure via the middleware defined below.
  set {
    name  = "ports.web.redirectTo.port"
    value = "websecure"
  }

  # TLS options — use cert-manager for certificate management.
  set {
    name  = "ports.websecure.tls.enabled"
    value = "true"
  }

  # Allow Ingress resources in any namespace to use this Traefik instance.
  set {
    name  = "providers.kubernetesIngress.allowCrossNamespace"
    value = "true"
  }

  set {
    name  = "providers.kubernetesCRD.allowCrossNamespace"
    value = "true"
  }
}

# Global HTTP→HTTPS redirect middleware.
# Reference this from Ingress annotations:
#   traefik.ingress.kubernetes.io/router.middlewares: traefik-redirect-to-https@kubernetescrd
resource "kubernetes_manifest" "redirect_middleware" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "redirect-to-https"
      namespace = var.namespace
    }
    spec = {
      redirectScheme = {
        scheme    = "https"
        permanent = true
      }
    }
  }

  depends_on = [helm_release.traefik]
}
