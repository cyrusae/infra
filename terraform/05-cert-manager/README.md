# cert-manager

Deploys cert-manager via Helm and configures Let's Encrypt DNS-01 issuers using Cloudflare.

**Apply order:** Layer 3, step 4. After `../metallb/`.  
**Depends on:** MetalLB (Traefik needs an IP before it can serve ACME HTTP-01 — but we use DNS-01 so this is a soft dependency). Apply before `../traefik/`.

---

## Secret Handling

The Cloudflare API token is **never committed to git**. Pass it at apply time via environment variable:

```bash
export TF_VAR_cloudflare_api_token="your-cloudflare-api-token"
terraform apply
```

The token requires these Cloudflare permissions for `dawnfire.casa`:

- `Zone:Read`
- `DNS:Edit`

Create a scoped token at: [https://dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)

---

## Apply

```bash
export TF_VAR_cloudflare_api_token="your-token"
terraform init
terraform plan
terraform apply
```

Verify ClusterIssuers are ready:

```bash
kubectl get clusterissuer
# Both should show READY=True within ~30 seconds
```

---

## Issuer Strategy

Two ClusterIssuers are created:

**`letsencrypt-staging`** — Use this first. Staging certs aren't browser-trusted but prove DNS-01 is working without consuming production rate limits. Point new Ingress resources at staging, verify the cert issues, then switch to prod.

**`letsencrypt-prod`** — Use once staging works. Subject to Let's Encrypt rate limits (50 certs/registered domain/week — well within homelab needs).

To use on an Ingress resource:

```yaml
annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"  # or letsencrypt-staging
```

---

## Troubleshooting

If a cert isn't issuing, check in order:

```bash
# Check Certificate resource
kubectl get certificate -n <namespace>
kubectl describe certificate <name> -n <namespace>

# Check CertificateRequest
kubectl get certificaterequest -n <namespace>

# Check Order and Challenge (DNS-01 challenge objects)
kubectl get order -n <namespace>
kubectl get challenge -n <namespace>
kubectl describe challenge <name> -n <namespace>
```

Common DNS-01 failures:

- Cloudflare token permissions too narrow (needs Zone:Read + DNS:Edit)
- Propagation delay — cert-manager waits for DNS to propagate before validating; can take 1–2 min

---

## Variables

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `chart_version` | `v1.19.3` | cert-manager Helm chart version |
| `namespace` | `cert-manager` | Deployment namespace |
| `acme_email` | `cyrus@dawnfire.casa` | Let's Encrypt account email |
| `cloudflare_api_token` | *(required)* | Cloudflare API token — pass via `TF_VAR_cloudflare_api_token` |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
