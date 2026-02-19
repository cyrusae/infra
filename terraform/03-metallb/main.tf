# MetalLB — L2 mode LoadBalancer for bare-metal Kubernetes.
#
# Apply order: Layer 3, step 3. After longhorn/ and storage-classes/.
# Traefik and Pi-hole both need MetalLB before they can get LoadBalancer IPs.
#
# The ghost-state incident (Feb 2026) was caused by corrupted memberlist gossip
# after a network isolation event. A clean install (no ghost state) avoids this.
# See ARCHIVE — Ghost Hunt and Rebuild Decision for the full post-mortem.

resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  wait    = true
  timeout = 300

  # MetalLB speakers use memberlist for L2 coordination.
  # No additional Helm values needed for L2 mode — pool config is via CRDs below.
}

# IPAddressPool and L2Advertisement are MetalLB CRDs installed by the Helm chart.
# We must wait for the Helm release to complete before creating these resources,
# otherwise the CRDs won't exist yet.

resource "kubernetes_manifest" "ip_address_pool" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = var.ip_pool_name
      namespace = var.namespace
    }
    spec = {
      addresses = [var.ip_pool_range]
    }
  }

  depends_on = [helm_release.metallb]
}

resource "kubernetes_manifest" "l2_advertisement" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "l2-advertisement"
      namespace = var.namespace
    }
    spec = {
      ipAddressPools = [var.ip_pool_name]
    }
  }

  depends_on = [kubernetes_manifest.ip_address_pool]
}
