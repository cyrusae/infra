# registry

Deploys a private Docker registry at `registry.dawnfire.casa`.

**Apply order:** Layer 5, step 2. After `../pihole/`.  
**Namespace:** `dawnfire` — shared with Homepage and other household services.

---

## Usage

```bash
# Push an image
docker tag myimage registry.dawnfire.casa/myimage:latest
docker push registry.dawnfire.casa/myimage:latest

# Pull in a K8s manifest
image: registry.dawnfire.casa/myimage:latest

# List images in registry (from any machine with DNS working)
curl https://registry.dawnfire.casa/v2/_catalog
```

K3s nodes need to trust the registry for image pulls. On each node, add to `/etc/rancher/k3s/registries.yaml` (Ansible layer2-k3s job):

```yaml
mirrors:
  registry.dawnfire.casa:
    endpoint:
      - "https://registry.dawnfire.casa"
```

---

## Storage

Uses `longhorn-bulk` (single replica) — images can be rebuilt from source if lost. Upgrade to `longhorn-duplicate` if you accumulate slow-to-rebuild images.

Default size: 20Gi. Expand by updating `storage_size` and running `terraform apply` — Longhorn supports online expansion.

---

## Auth

No authentication configured by default. The registry is only reachable via Traefik Ingress on the local network or Tailscale — not publicly exposed. If you add a Cloudflare tunnel or public Ingress, add htpasswd auth first.

---

## Homepage Discovery

This module includes `gethomepage.dev/` annotations on the Ingress. When Homepage is deployed with cluster RBAC (see `../homepage/`), the registry tile appears automatically under the "Infrastructure" group.

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `namespace` | `dawnfire` | Deployment namespace |
| `storage_class` | `longhorn-bulk` | Storage class for registry PVC |
| `storage_size` | `20Gi` | Registry PVC size |
| `hostname` | `registry.dawnfire.casa` | Ingress hostname |
| `cert_issuer` | `letsencrypt-staging` | cert-manager ClusterIssuer |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
