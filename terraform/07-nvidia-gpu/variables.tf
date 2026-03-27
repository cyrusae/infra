###############################################################################
# terraform/nvidia-gpu/variables.tf
###############################################################################
variable "kubeconfig_path" {
  description = "Path to kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "kubeconfig context to use. Leave empty to use the current context."
  type        = string
  default     = ""
}

variable "gpu_time_slices" {
  description = <<-EOT
    Number of virtual GPU replicas to expose per physical GPU via time-slicing.

    Current hardware: GTX 1070 (8 GB VRAM).

    Expected workloads and rough VRAM footprint:
      - Ollama (7B quantized):   ~4-6 GB  -- long-lived, always-on
      - GROBID (GPU models):     ~2-4 GB  -- bursty, document processing
      - Whisper (large-v2):      ~3-4 GB  -- bursty, transcription jobs
      - OCR (easyocr/surya):     ~1-2 GB  -- bursty

    WARNING: time-slicing does NOT partition VRAM. All replicas share the
    full 8 GB pool. If Ollama and GROBID run simultaneously they may OOM
    each other. Start at 8 and reduce if you see GPU OOM errors:
      kubectl logs -n <namespace> <pod> | grep -i "out of memory"
    
    Reducing to 4 gives the scheduler less over-commit but is still enough
    for all expected workloads to be schedulable.
  EOT
  type        = number
  default     = 8
}

variable "chart_version" {
  description = <<-EOT
    Helm chart version for the NVIDIA device plugin.
    Pin this to avoid surprise upgrades. Check for new releases at:
    https://github.com/NVIDIA/k8s-device-plugin/releases
    Last verified working: 0.19.0 (Mar 2026)
  EOT
  type        = string
  default     = "0.19.0"
}

variable "taint_gpu_node" {
  description = <<-EOT
    Whether to taint Babbage with nvidia.com/gpu=present:NoSchedule.

    When true, only pods that explicitly tolerate the taint (i.e. GPU
    workloads) will schedule on Babbage. Non-GPU workloads will be pushed
    to Epimetheus and Kabandha.

    Trade-off:
      true  -- Babbage's CPU/RAM reserved for GPU workloads; cleaner
               resource isolation; requires toleration in every GPU pod spec
      false -- All workloads can land anywhere; simpler; risk of non-GPU
               pods starving GPU workloads of CPU/RAM on Babbage

    NOTE: Setting this to true here only configures the tolerations in the
    device plugin DaemonSet (so it can still schedule on Babbage). The
    actual taint must be applied to the Babbage node separately:
      kubectl taint nodes babbage nvidia.com/gpu=present:NoSchedule
    This is best done in the Ansible babbage_quirks role post-K3s-join.

    Recommended: false for now (homelab, workloads are light); revisit when
    GPU contention becomes a problem.
  EOT
  type        = bool
  default     = false
}
