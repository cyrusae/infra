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

# Replica counts per tier — adjust these when adding nodes or changing durability posture.

variable "replicas_critical" {
  description = "Replica count for longhorn-critical. Should equal number of always-on nodes (currently 3)."
  type        = number
  default     = 3
}

variable "replicas_duplicate" {
  description = "Replica count for longhorn-duplicate. Two copies on nodes with most free space."
  type        = number
  default     = 2
}

variable "replicas_bulk" {
  description = "Replica count for longhorn-bulk. Single copy, placed wherever space is available."
  type        = number
  default     = 1
}

# longhorn-sticky has replicas=1 by definition (follows its pod).
# No variable needed — if you want more replicas, you want a different tier.
