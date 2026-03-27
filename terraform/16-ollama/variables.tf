###############################################################################
# terraform/ollama/variables.tf
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

variable "namespace" {
  description = "Namespace to deploy Ollama into."
  type        = string
  default     = "ollama"
}

variable "hostname" {
  description = "Hostname for the optional Ollama Ingress. Leave empty to skip Ingress creation (internal-only access)."
  type        = string
  default     = "ollama.dawnfire.casa"
}

variable "expose_ingress" {
  description = "Whether to create a Traefik Ingress for the Ollama API. Internal cluster access via ClusterIP service always works regardless. Enable the Ingress to use the Letta ADE (agent development environment) from outside the cluster."
  type        = bool
  default     = true
}

variable "cert_issuer" {
  description = "cert-manager ClusterIssuer for the Ingress TLS."
  type        = string
  default     = "letsencrypt-prod"
}

variable "gpu_node_hostname" {
  description = "Kubernetes node hostname to pin Ollama to. Must be the node with the NVIDIA GPU. Ollama falls back to CPU if no GPU is available, but performance will be severely degraded for large models. Check your node name with: kubectl get nodes"
  type        = string
  default     = "babbage"
}

variable "model_storage_class" {
  description = "Storage class for the model weights PVC. Use local-path for speed — models can be re-pulled from the internet, they're not original data."
  type        = string
  default     = "local-path"
}

variable "model_storage_size" {
  description = "PVC size for Ollama model weights. Size this for your expected model set: nomic-embed-text (~274MB), mistral-7b (~4.1GB), llama3.1:8b (~4.7GB), llama3.1:70b (~40GB). 40Gi is comfortable for several small-to-mid models."
  type        = string
  default     = "50Gi"
}

variable "ollama_image" {
  description = "Ollama Docker image tag."
  type        = string
  default     = "ollama/ollama:latest"
}
