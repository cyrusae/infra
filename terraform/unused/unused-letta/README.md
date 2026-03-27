# letta

Deploys the Letta stateful AI agent server at `letta.dawnfire.casa`.

**Apply order:** Layer 5, step 5. After `../ollama/` (if using local embeddings).  
**Storage:** `longhorn-critical` for PostgreSQL/pgvector (agent memory is valuable data).

---

## Architecture

```
letta-db (Deployment)
  └── pgvector/pgvector:pg17
  └── PVC: letta-db (longhorn-critical, 10Gi)
  └── ConfigMap: letta-db-init (CREATE EXTENSION vector)

letta (Deployment)
  └── letta/letta:<version>  (app container only — no bundled Postgres)
  └── init-container: wait-for-db
  └── Connects to letta-db ClusterIP via LETTA_PG_* env vars

Ingress: letta.dawnfire.casa → letta:8283
```

Why not use the all-in-one `letta/letta` image as-is? The image bundles PostgreSQL, Redis, Node.js, and an OpenTelemetry collector — convenient for `docker run` but wrong for Kubernetes. A pod restart would risk all agent state. The app and database lifecycles must be independent.

---

## First Deploy

```bash
export TF_VAR_server_password="$(openssl rand -hex 24)"
export TF_VAR_db_password="$(openssl rand -hex 24)"

# At minimum one LLM provider. Mix and match — all are optional.
export TF_VAR_anthropic_api_key="sk-ant-..."
export TF_VAR_openai_api_key="sk-..."
# Ollama is configured via ollama_base_url variable (defaults to internal cluster URL)

terraform init
terraform plan
terraform apply
```

**First boot is slow.** Letta runs ~150 Alembic database migrations on startup. Expect 60–120 seconds before the readiness probe passes. Monitor progress:

```bash
kubectl logs -n letta -l app=letta --follow
```

---

## Connecting with the Python SDK

```bash
pip install letta-client
```

```python
from letta_client import Letta

client = Letta(
    base_url="https://letta.dawnfire.casa",
    token="your-server-password",
)

# Create an agent using a local Ollama model for chat:
agent = client.agents.create(
    name="homelab-assistant",
    model="ollama/mistral:7b-instruct",
    embedding="ollama/nomic-embed-text",
)

# Or use Anthropic:
agent = client.agents.create(
    name="homelab-assistant",
    model="claude-sonnet-4-5",
    embedding="ollama/nomic-embed-text",  # embeddings stay local regardless
)
```

The embedding model can be local (Ollama) even when the chat model is cloud-hosted. This is the recommended approach: local embeddings (fast, private, no API cost) + cloud LLM (better reasoning).

---

## Connecting with the Letta ADE

The [Agent Development Environment](https://app.letta.com) at `app.letta.com` can connect to self-hosted servers:

1. Go to `app.letta.com`
2. Settings → Server → Add Custom Server
3. URL: `https://letta.dawnfire.casa`
4. API Key: your `TF_VAR_server_password` value

The ADE provides a GUI for creating agents, browsing memory blocks, and running conversations — useful for experimentation without writing SDK code.

---

## Embedding models

Letta uses embeddings for **archival memory** — the long-term storage that gets vector-searched when an agent needs to retrieve past information. The embedding model must be consistent: all passages are stored with the same model's vector representations, so you can't switch models without re-embedding everything.

**Recommended: `nomic-embed-text` via Ollama**
- 274MB, 768 dimensions
- Runs entirely on the GTX 1080 (or CPU — it's small enough)
- No API costs, no data leaving your network
- Excellent quality/size ratio for semantic search

Configure when creating agents:
```python
agent = client.agents.create(
    embedding="ollama/nomic-embed-text",
    # ...
)
```

Ensure the ollama/ module is applied first and the model is pulled:
```bash
kubectl exec -n ollama deploy/ollama -- ollama pull nomic-embed-text
```

---

## Letta vs. image version pinning

Letta releases frequently. `latest` works but can introduce breaking changes. Once you've created agents you care about, pin `letta_image` to the version you tested with:

```hcl
# terraform.tfvars (gitignored)
letta_image = "letta/letta:0.16.4"
```

Before upgrading, check the [changelog](https://docs.letta.com/api-reference/changelog) for migration notes. The October 2025 `letta_v1_agent` rearchitecture was the last major breaking change — anything after that should be incremental.

---

## Pre-teardown checklist

Before destroying this module or the cluster:

- [ ] Take a Longhorn snapshot of the `letta-db` PVC
- [ ] Note the Letta image version (for consistency on restore)
- [ ] Export any agents you want to keep:
  ```bash
  # Using the CLI:
  letta agent export <agent-id> --output agent-backup.json
  ```

---

## Backup and restore

The PVC (`letta-db`) contains everything: agents, memory blocks, messages, and archival passages. A Longhorn snapshot of this PVC is a complete backup.

To restore:
1. Apply this module (creates namespace, secrets, services, PVC)
2. **Before** starting the pods: restore the PVC from snapshot via Longhorn UI
3. Re-apply with the same image version that created the snapshot
4. First boot will detect existing schema and skip migrations

---

## Variables

| Variable | Default | Description |
|---|---|---|
| `namespace` | `letta` | Kubernetes namespace |
| `hostname` | `letta.dawnfire.casa` | Ingress hostname |
| `cert_issuer` | `letsencrypt-staging` | Switch to `letsencrypt-prod` once staging works |
| `letta_image` | `letta/letta:latest` | Pin to a specific tag for stability |
| `server_password` | *(required)* | Letta API authentication |
| `db_password` | *(required)* | PostgreSQL letta user password |
| `openai_api_key` | `""` | OpenAI (optional) |
| `anthropic_api_key` | `""` | Anthropic (optional) |
| `ollama_base_url` | `http://ollama.ollama.svc.cluster.local:11434` | Local Ollama; empty to disable |
| `uvicorn_workers` | `1` | API worker count |
| `db_pool_size` | `20` | DB connections per worker |
| `db_storage_class` | `longhorn-critical` | Storage tier for PostgreSQL PVC |
| `db_storage_size` | `10Gi` | PVC size |
