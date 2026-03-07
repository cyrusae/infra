
variable "grobid_version" {
  description = "GROBID version to deploy (must use grobid/grobid repo, not mirror)"
  type        = string
  default     = "0.8.2-full"  # Latest stable; full image with DL + CRF models
}

variable "grobid_replicas" {
  description = "Number of GROBID server replicas (runs only on gpu=true nodes)"
  type        = number
  default     = 1  # Single persistent instance for caching; adjust if load increases
}

variable "grobid_storage_size" {
  description = "Storage size for GROBID working directory and model cache"
  type        = string
  default     = "15Gi"  # Full image + models + working space
}

variable "grobid_worker_threads" {
  description = "GROBID worker threads for PDF processing (production tuning)"
  type        = number
  default     = 4  # Conservative for shared GPU; increase if CPU-bound
}

variable "grobid_max_concurrent_requests" {
  description = "Max concurrent PDF processing requests"
  type        = number
  default     = 5  # Prevents queue blow-up on bursty loads
}

variable "grobid_namespace" {
  description = "Kubernetes namespace for GROBID deployment"
  type        = string
  default     = "grobid"
}

variable "domain" {
  description = "Primary domain for Ingress (e.g., dawnfire.casa)"
  type        = string
  default     = "dawnfire.casa"
}
