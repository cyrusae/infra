# traefik

Deploys Traefik as the cluster ingress controller via Helm.

**Apply order:** Layer 3, step 5 (final layer 3 step). After `../cert-manager/`.  
**Depends on:** MetalLB (for LoadBalancer IP) and cert-manager (ClusterIssuers must exist before certs can issue).

---

## K3s Built-in Traefik

K3s ships with its own Traefik instance. We manage Traefik ourselves for version control and configuration ownership. **Disable the K3s built-in in Ansible `layer2-k3s`** by including in `/etc/rancher/k3s/config.yaml`:

```yaml
disable:
  - traefik
```

If you forget this, two Traefik instances will compete for port 80/443 and you'll get phantom port conflicts.

---

## Architecture

Traefik gets `192.168.4.240` (first MetalLB IP) as a stable LoadBalancer IP. All `*.dawnfire.casa` wildcard DNS points here. Pi-hole serves DNS on `192.168.4.241:53` with a custom entry: `*.dawnfire.casa → 192.168.4.240`.

Port layout:

- `:80` — HTTP, immediately redirects to HTTPS via `redirect-to-https` middleware
- `:443` — HTTPS, TLS terminated by Traefik using cert-manager certificates

---

## Apply

```bash
terraform init
terraform plan
terraform apply
```

Verify Traefik has its LoadBalancer IP:

```bash
kubectl get svc -n traefik
# EXTERNAL-IP should be 192.168.4.240
```

---

## Using the Redirect Middleware

The `redirect-to-https` Middleware is created in the `traefik` namespace. Reference it from any Ingress:

```yaml
annotations:
  traefik.ingress.kubernetes.io/router.middlewares: "traefik-redirect-to-https@kubernetescrd"
```

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `chart_version` | `39.1.0` | Traefik Helm chart version |
| `namespace` | `traefik` | Deployment namespace |
| `load_balancer_ip` | `192.168.4.240` | Static IP from MetalLB pool |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
