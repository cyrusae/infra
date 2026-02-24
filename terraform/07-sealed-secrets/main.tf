# -----------------------------------------------------------------------------
# Sealed Secrets Controller
#
# Decrypts SealedSecret CRs into plain Secrets in-cluster.
# The controller's private key is stored in kube-system/sealed-secrets-key.
# BACK THIS UP to Bitwarden before destroying the cluster:
#
#   kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key \
#     -o yaml > sealed-secrets-master-key.yaml
#
# On rebuild, restore it BEFORE applying this module:
#
#   kubectl apply -f sealed-secrets-master-key.yaml
#   # Then apply this module — controller picks up the existing key
#
# Without the backup, all SealedSecrets become unrecoverable on cluster destroy.
# -----------------------------------------------------------------------------

resource "helm_release" "sealed_secrets" {
  name             = "sealed-secrets"
  repository       = "https://bitnami-labs.github.io/sealed-secrets"
  chart            = "sealed-secrets"
  version          = var.chart_version
  namespace        = "kube-system"
  atomic           = true
  cleanup_on_fail  = true
  timeout          = 120

  # Controller manages its own key rotation; don't override defaults.
  # Key renewal period defaults to 30 days; keys are added not replaced,
  # so old SealedSecrets continue to work after rotation.
  set = {
    name  = "fullnameOverride"
    value = "sealed-secrets-controller"
  }
}
