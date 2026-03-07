# ollama

Deploys Ollama local LLM inference server on Babbage (GTX 1080), pinned to the GPU node.

**Apply order:** Layer 5, step 4.5. After `../nvidia-gpu/` (Layer 3), before `../letta/`.  
**Storage:** `longhorn-bulk` (1 replica) for model weights — models are re-pullable.

---

## Architecture

```
ollama (Deployment)
  └── ollama/ollama:latest
  └── RuntimeClass: nvidia  (from nvidia-gpu/ module)
  └── nodeAffinity: kubernetes.io/hostname = babbage
  └── GPU resource request: nvidia.com/gpu = 1
  └── PVC: ollama-models (longhorn-bulk, 40Gi)

Service: ollama (ClusterIP, port 11434)
  └── http://ollama.ollama.svc.cluster.local:11434

Ingress: ollama.dawnfire.casa (optional, var.expose_ingress)
```

---

## First Deploy

```bash
terraform init
terraform plan
terraform apply

# After apply, pull the embedding model used by Letta:
kubectl exec -n ollama deploy/ollama -- ollama pull nomic-embed-text

# Verify:
kubectl exec -n ollama deploy/ollama -- ollama list
```

---

## Embedding model for Letta

The embedding model underpins Letta's archival memory (pgvector search). Pull it before using Letta:

```bash
kubectl exec -n ollama deploy/ollama -- ollama pull nomic-embed-text
```

`nomic-embed-text` is the recommended choice:
- **274MB** — tiny, fits entirely in VRAM alongside a chat model
- **768 dimensions** — enough for good semantic recall
- **OpenAI-compatible** via Ollama's `/api/embeddings` endpoint
- No API cost, no data leaving the cluster

If you need higher-quality embeddings at larger size: `mxbai-embed-large` (670MB, 1024 dims).

---

## Chat models for the GTX 1080 (8GB VRAM)

Models that fit in VRAM (fast inference):

| Model | VRAM | Notes |
|---|---|---|
| `phi3:mini` | ~2.2GB | Tiny and fast, good at tool use |
| `mistral:7b-instruct` | ~4.1GB | Good general-purpose |
| `llama3.1:8b` | ~4.7GB | Strong reasoning, Letta-tested |
| `deepseek-r1:7b` | ~4.7GB | Good for code/analysis |
| `nomic-embed-text` | ~0.3GB | Embedding only (for Letta) |

Models that exceed VRAM (CPU offload, slow):

| Model | Size | Notes |
|---|---|---|
| `llama3.1:70b-q2_K` | ~25GB | Possible but ~10x slower |

**Practical recommendation:** Run `nomic-embed-text` (always) + one 7B chat model. The 1080 can handle one chat model + the embedding model in VRAM simultaneously.

---

## Pulling models

```bash
# Pull a model:
kubectl exec -n ollama deploy/ollama -- ollama pull <model>

# List pulled models:
kubectl exec -n ollama deploy/ollama -- ollama list

# Remove a model:
kubectl exec -n ollama deploy/ollama -- ollama rm <model>

# Check GPU utilization during inference:
kubectl exec -n letta deploy/letta -- bash  # then query Letta
# On Babbage:
nvidia-smi dmon
```

---

## Security note on the Ingress

Ollama has **no built-in authentication**. The Ingress exposes the full API including model pull/delete operations. `expose_ingress = true` is convenient but means anyone who can reach `ollama.dawnfire.casa` can pull models and saturate Babbage's disk.

For now this is acceptable given LAN + Tailscale access controls. If you add port forwarding later, consider a Traefik BasicAuth middleware:

```hcl
# In main.tf annotations:
"traefik.ingress.kubernetes.io/router.middlewares" = "ollama-auth@kubernetescrd"
```

---

## Connecting from development machines

Via kubectl port-forward (no Ingress needed):
```bash
kubectl port-forward -n ollama svc/ollama 11434:11434
# Then: curl http://localhost:11434/api/tags
```

Via Ingress (if `expose_ingress = true`):
```bash
curl https://ollama.dawnfire.casa/api/tags
```

Via Tailscale (any node in the tailnet can reach the ClusterIP after port-forwarding, or expose on a node port):
```bash
# On Babbage directly (Ollama ClusterIP is accessible from the node):
curl http://10.43.x.x:11434/api/tags  # use actual ClusterIP
```

---

## Variables

| Variable | Default | Description |
|---|---|---|
| `namespace` | `ollama` | Kubernetes namespace |
| `hostname` | `ollama.dawnfire.casa` | Ingress hostname (only used if `expose_ingress = true`) |
| `expose_ingress` | `true` | Create Traefik Ingress |
| `cert_issuer` | `letsencrypt-staging` | TLS issuer |
| `gpu_node_hostname` | `babbage` | Node to pin Ollama to |
| `model_storage_class` | `longhorn-bulk` | PVC storage class |
| `model_storage_size` | `40Gi` | PVC size for model weights |
| `ollama_image` | `ollama/ollama:latest` | Ollama image tag |
