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
  description = "Namespace to deploy Letta into."
  type        = string
  default     = "letta"
}

variable "hostname" {
  description = "Hostname for the Letta Ingress."
  type        = string
  default     = "letta.dawnfire.casa"
}

variable "cert_issuer" {
  description = "cert-manager ClusterIssuer for the Ingress TLS."
  type        = string
  default     = "letsencrypt-staging"
}

variable "letta_image" {
  description = "Letta Docker image. Letta moves fast — pin this to a specific version tag for stability."
  type        = string
  default     = "letta/letta:latest"
}

# -------------------------------------------------------------------------
# Secrets — all passed via TF_VAR_* environment variables
# -------------------------------------------------------------------------

variable "server_password" {
  description = "Password for the Letta server API. Pass via TF_VAR_server_password — never commit."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL password for the letta user. Pass via TF_VAR_db_password — never commit."
  type        = string
  sensitive   = true
}

# -------------------------------------------------------------------------
# LLM / embedding providers
# All optional. Set the ones you use; leave the rest empty.
# -------------------------------------------------------------------------

variable "openai_api_key" {
  description = "OpenAI API key. Leave empty to disable OpenAI provider."
  type        = string
  sensitive   = true
  default     = ""
}

variable "anthropic_api_key" {
  description = "Anthropic API key. Leave empty to disable Anthropic provider."
  type        = string
  sensitive   = true
  default     = ""
}

variable "ollama_base_url" {
  description = "Base URL for a local Ollama instance. Used for both chat and embedding models."
  type        = string
  # Points to the Ollama ClusterIP service in the ollama namespace.
  # If you haven't deployed the ollama/ module yet, leave this empty.
  default     = "http://ollama.ollama.svc.cluster.local:11434"
}

# -------------------------------------------------------------------------
# Server tuning
# -------------------------------------------------------------------------

variable "uvicorn_workers" {
  description = "Number of Uvicorn worker processes. 1 is correct for a single-node homelab; increase if you notice latency under concurrent agent calls. Each worker has its own DB connection pool — adjust db_pool_size accordingly."
  type        = number
  default     = 1
}

variable "db_pool_size" {
  description = "PostgreSQL connection pool size per Uvicorn worker."
  type        = number
  default     = 20
}

# -------------------------------------------------------------------------
# Storage
# -------------------------------------------------------------------------

variable "db_storage_class" {
  description = "Storage class for the PostgreSQL PVC. Agent memory, messages, and archival passages live here — use a replicated tier."
  type        = string
  default     = "longhorn-critical"
}

variable "db_storage_size" {
  description = "PostgreSQL PVC size. Agent archival memory accumulates in pgvector — start generous."
  type        = string
  default     = "10Gi"
}
