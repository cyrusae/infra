resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  # Wait for all Longhorn pods to be ready before Terraform considers this done.
  # Required: storage-classes/ module depends on Longhorn CRDs existing.
  wait    = true
  timeout = 600 # Longhorn takes a while on first install (image pulls + CRD registration)

  set = [{
    name  = "defaultSettings.defaultReplicaCount"
    value = var.replica_count
  },
  {
    name  = "defaultSettings.storageOverProvisioningPercentage"
    value = var.storage_over_provisioning_percentage
  }, 
  {
    name  = "defaultSettings.storageMinimalAvailablePercentage"
    value = var.storage_minimal_available_percentage
  },

  # Longhorn UI is exposed via Traefik Ingress (see traefik/ module).
  # We disable the default Longhorn frontend service here to avoid ambiguity.
  ### (Why? Why does that avoid ambiguity and how?)
  {
    name  = "ingress.enabled"
    value = "false"
  }]

  # Node-level prerequisites (open-iscsi, nfs-client) are Ansible's job (layer1-base).
  # If those aren't present, Longhorn manager pods will fail to start — check node logs.
}
