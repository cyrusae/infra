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

variable "namespace" {
  description = "Namespace to deploy Nextcloud into."
  type        = string
  default     = "nextcloud"
}

variable "hostname" {
  description = "Hostname for the Nextcloud Ingress."
  type        = string
  default     = "nextcloud.dawnfire.casa"
}

variable "cert_issuer" {
  description = "cert-manager ClusterIssuer for the Nextcloud Ingress."
  type        = string
  default     = "letsencrypt-staging"
}

# -------------------------------------------------------------------------
# Secrets — all passed via TF_VAR_* environment variables
# -------------------------------------------------------------------------

variable "nextcloud_admin_password" {
  description = "Nextcloud admin account password."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL database password for Nextcloud."
  type        = string
  sensitive   = true
}

variable "db_root_password" {
  description = "PostgreSQL superuser password."
  type        = string
  sensitive   = true
}

# -------------------------------------------------------------------------
# Storage
# -------------------------------------------------------------------------

variable "data_storage_class" {
  description = "Storage class for the Nextcloud data PVC (user files, calendars). Use longhorn-critical — this is the most important data in the cluster."
  type        = string
  default     = "longhorn-critical"
}

variable "db_storage_class" {
  description = "Storage class for the PostgreSQL database PVC."
  type        = string
  default     = "longhorn-critical"
}

variable "data_storage_size" {
  description = "Nextcloud data PVC size."
  type        = string
  default     = "50Gi"
}

variable "db_storage_size" {
  description = "PostgreSQL PVC size."
  type        = string
  default     = "5Gi"
}

# -------------------------------------------------------------------------
# Restore mode
# -------------------------------------------------------------------------

variable "restore_from_backup" {
  description = "Set to true when restoring from a PVC backup snapshot. When true, Terraform will not pre-populate the data PVC and will expect you to restore manually before starting the pod."
  type        = bool
  default     = false
}
