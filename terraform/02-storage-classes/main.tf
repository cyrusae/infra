# Storage class definitions for the dawnfire.casa cluster.
#
# Tier summary:
#   longhorn-critical  — 3 replicas, one per node. For etcd, certs, anything that must survive node loss.
#   longhorn-duplicate — 2 replicas, best-effort placement. For important-but-recoverable data (Pi-hole, registry).
#   longhorn-bulk      — 1 replica, most space available. For large/cheap data (media, downloads).
#   longhorn-sticky    — 1 replica, WaitForFirstConsumer. Pod and volume land on the same node and stay together.
#
# Apply AFTER longhorn/ — Longhorn CRDs must exist for these resources to register.
# Changing numberOfReplicas or dataLocality requires deleting and recreating the StorageClass (immutable fields).
# PVCs are NOT affected by StorageClass changes — existing volumes keep their current configuration.

resource "kubernetes_storage_class" "longhorn_critical" {
  metadata {
    name = "longhorn-critical"
    annotations = {
      # Not the cluster default — local-path remains the K3s default for simplicity.
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "driver.longhorn.io"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true

  parameters = {
    numberOfReplicas    = tostring(var.replicas_critical)
    dataLocality        = "best-effort"
    fromBackup          = ""
    fsType              = "ext4"
  }
}

resource "kubernetes_storage_class" "longhorn_duplicate" {
  metadata {
    name = "longhorn-duplicate"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "driver.longhorn.io"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true

  parameters = {
    numberOfReplicas    = tostring(var.replicas_duplicate)
    dataLocality        = "disabled"
    fromBackup          = ""
    fsType              = "ext4"
  }
}

resource "kubernetes_storage_class" "longhorn_bulk" {
  metadata {
    name = "longhorn-bulk"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "driver.longhorn.io"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true

  parameters = {
    numberOfReplicas    = tostring(var.replicas_bulk)
    dataLocality        = "disabled"
    fromBackup          = ""
    fsType              = "ext4"
  }
}

resource "kubernetes_storage_class" "longhorn_sticky" {
  metadata {
    name = "longhorn-sticky"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "driver.longhorn.io"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer" # Must be WaitForFirstConsumer for strict-local to work
  allow_volume_expansion = true

  parameters = {
    numberOfReplicas    = "1"
    dataLocality        = "strict-local" # Volume lives on whichever node the pod lands on
    fromBackup          = ""
    fsType              = "ext4"
  }
}
