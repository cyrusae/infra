# cert-manager — automatic TLS certificates via Let's Encrypt DNS-01 challenge (Cloudflare).
#
# Apply order: Layer 3, step 4. After metallb/.
# Traefik depends on cert-manager ClusterIssuers existing before it can issue certificates.
#
# Secret handling: The Cloudflare API token is passed via TF_VAR_cloudflare_api_token
# (environment variable) and stored as a Kubernetes Secret. It will appear in Terraform
# state (sensitive = true masks it in plan output but not in raw state files).
# Keep state files out of git — they are gitignored.

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  wait    = true
  timeout = 300

  set = {
    name  = "crds.enabled"
    value = "true"
  }
}

# Cloudflare API token — used by cert-manager for DNS-01 challenge.
# Pass via environment: export TF_VAR_cloudflare_api_token="your-token"
# Token needs: Zone:Read + DNS:Edit on dawnfire.casa.
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = var.namespace
  }

  data = {
    api-token = var.cloudflare_api_token
  }

  type = "Opaque"

  depends_on = [helm_release.cert_manager]
}

# Staging issuer — use this first to verify DNS-01 works without burning rate limits.
# Certificates issued by staging are not trusted by browsers (self-signed CA).
resource "kubernetes_manifest" "cluster_issuer_staging" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
    }
    spec = {
      acme = {
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = var.acme_email
        privateKeySecretRef = {
          name = "letsencrypt-staging-account-key"
        }
        solvers = [
          {
            dns01 = {
              cloudflare = {
                apiTokenSecretRef = {
                  name = kubernetes_secret.cloudflare_api_token.metadata[0].name
                  key  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [kubernetes_secret.cloudflare_api_token]
}

# Production issuer — use after staging confirms DNS-01 is working.
# Subject to Let's Encrypt rate limits (50 certs/domain/week).
resource "kubernetes_manifest" "cluster_issuer_prod" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.acme_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [
          {
            dns01 = {
              cloudflare = {
                apiTokenSecretRef = {
                  name = kubernetes_secret.cloudflare_api_token.metadata[0].name
                  key  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [kubernetes_secret.cloudflare_api_token]
}
