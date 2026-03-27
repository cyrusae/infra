###############################################################################
# terraform/nvidia-gpu/main.tf
#
# Deploys NVIDIA GPU support into the cluster:
#   1. A ConfigMap enabling time-slicing (N virtual GPUs per physical GPU)
#   2. The NVIDIA device plugin DaemonSet (Helm) - advertises nvidia.com/gpu
#      resources to the scheduler, reads the time-slicing ConfigMap
#   3. A RuntimeClass named "nvidia" - workloads that need GPU declare
#      runtimeClassName: nvidia in their pod spec
#
# Layer: 3 (core infrastructure) -- deploy after K3s, before Layer 4/5.
# The host-side prerequisite (nvidia-container-toolkit) is handled by
# Ansible roles/common on ALL nodes.
#
# Apply:
#   TF_VAR_gpu_time_slices=8 terraform apply
#
# Verify post-apply:
#   kubectl describe node babbage | grep -A5 "nvidia.com/gpu"
#   # Should show:  nvidia.com/gpu: <N>   (N = var.gpu_time_slices)
##############################################################################

###############################################################################
# 1. Time-slicing ConfigMap
#
# The device plugin reads this ConfigMap at startup to learn how many virtual
# GPU replicas to advertise per physical GPU.
#
# IMPORTANT: time-slicing does NOT partition VRAM. All slices share the full
# 8 GB pool. The GTX 1070 is small enough that concurrent VRAM-heavy workloads
# (e.g. Ollama 7B + GROBID simultaneously) may OOM each other. Monitor and
# reduce var.gpu_time_slices if you see OOM errors in GPU workloads.
#
# ConfigMap name must match the Helm value `config.name` below.
###############################################################################

resource "kubernetes_config_map_v1" "time_slicing" {
  metadata {
    name      = "nvidia-device-plugin-config"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "config.yaml" = yamlencode({
      version = "v1"
      sharing = {
        timeSlicing = {
          resources = [
            {
              name     = "nvidia.com/gpu"
              replicas = var.gpu_time_slices
            }
          ]
        }
      }
    })
  }
}

###############################################################################
# 2. NVIDIA device plugin (Helm)
#
# Chart: https://helm.ngc.nvidia.com/nvidia/charts/nvidia-device-plugin
# The chart deploys a DaemonSet that runs only on nodes with:
#   feature.node.kubernetes.io/pci-10de.present: "true"
# (i.e. nodes with an NVIDIA PCI device -- Babbage only, currently)
#
# config.name must match the ConfigMap name above.
###############################################################################

resource "helm_release" "nvidia_device_plugin" {
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = var.chart_version
  namespace  = "kube-system"

  # Point the plugin at the time-slicing ConfigMap
  set = [{
    name  = "config.name"
    value = kubernetes_config_map_v1.time_slicing.metadata[0].name
  },

  # Tolerate the nvidia taint so GPU pods can land on Babbage.
  # If you add var.taint_gpu_node = true, this taint is added to Babbage
  # by the babbage_quirks Ansible role (see variables.tf notes).
  {
    name  = "tolerations[0].key"
    value = "nvidia.com/gpu"
  },
  {
    name  = "tolerations[0].operator"
    value = "Exists"
  },
  {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }]

  depends_on = [kubernetes_config_map_v1.time_slicing]
}

###############################################################################
# 3. RuntimeClass: nvidia
#
# Workloads that need GPU declare:
#   runtimeClassName: nvidia
#
# This tells the kubelet to use the nvidia-container-runtime shim, which
# injects GPU device access into the container. Without this, requesting
# nvidia.com/gpu resources will fail even with the device plugin running.
#
# The handler name "nvidia" must match what nvidia-ctk configured in
# /etc/containerd/config.toml (done by nvidia-container-toolkit on all nodes).
###############################################################################

resource "kubernetes_runtime_class_v1" "nvidia" {
  metadata {
    name = "nvidia"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  handler = "nvidia"
}
