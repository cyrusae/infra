# pihole

Deploys Pi-hole for network-wide DNS and ad blocking.

**Apply order:** Layer 5, step 1. After all Layer 3 (core) and Layer 4 (monitoring) modules.

---

## Architecture

The pre-rebuild cluster had Pi-hole using a LoadBalancer on ports 80, 443, and 53 — which conflicted with Traefik's ports and caused phantom port reservations. This is fixed:

- **DNS:** LoadBalancer on port 53 only, IP `192.168.4.241`
- **Web UI:** ClusterIP service + Traefik Ingress at `https://pihole.dawnfire.casa/admin`
- No host ports. No conflict with Traefik.

**HA model:** Single pod + `longhorn-duplicate` storage + MetalLB stable IP.
Failover time: ~30-45s total (MetalLB IP reassignment + pod reschedule + Longhorn reattach). Devices fall back to secondary DNS (1.1.1.1) during this window.

---

## Apply

```bash
export TF_VAR_pihole_password="your-admin-password"
terraform init
terraform plan
terraform apply
```

---

## After Apply — DNS Cutover

Verify Pi-hole is serving DNS before switching Eero:

```bash
# From any machine on the network
nslookup pihole.dawnfire.casa 192.168.4.241
# Should return 192.168.4.240 (Traefik IP)

nslookup google.com 192.168.4.241
# Should return a real IP
```

Then in Eero app: Network Settings → DNS → Custom:

- Primary: `192.168.4.241`
- Secondary: `1.1.1.1`

Also disable **Eero Secure** and **Eero DNS Caching** — both bypass Pi-hole.

---

## Custom DNS

Pi-hole resolves `*.dawnfire.casa` → `192.168.4.240` (Traefik) via a dnsmasq config mounted from a ConfigMap. If Traefik's IP ever changes, update `traefik_ip` variable and re-apply — the ConfigMap will update and Pi-hole will pick it up on next restart.

---

## Variables

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `namespace` | `pihole` | Deployment namespace |
| `pihole_password` | *(required)* | Admin panel password — pass via `TF_VAR_pihole_password` |
| `upstream_dns_1` | `1.1.1.1` | Primary upstream DNS |
| `upstream_dns_2` | `8.8.8.8` | Secondary upstream DNS |
| `timezone` | `America/New_York` | Container timezone |
| `load_balancer_ip` | `192.168.4.241` | DNS LoadBalancer IP (MetalLB pool) |
| `traefik_ip` | `192.168.4.240` | Traefik IP — used in wildcard DNS entry |
| `storage_class` | `longhorn-duplicate` | Storage class for PVCs |
| `config_storage_size` | `1Gi` | Config PVC size |
| `dnsmasq_storage_size` | `500Mi` | dnsmasq PVC size |
| `cert_issuer` | `letsencrypt-staging` | cert-manager ClusterIssuer |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
