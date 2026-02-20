# metallb

Deploys MetalLB in L2 mode via Helm, and configures the IP address pool for LoadBalancer services.

**Apply order:** Layer 3, step 3. After `../longhorn/` and `../storage-classes/`.  
**Depends on:** A healthy 3-node K3s cluster. Longhorn not strictly required, but apply order is conventional.

---

## IP Allocation

MetalLB pool: `192.168.4.240–192.168.4.254` (15 addresses)  
Eero DHCP pool ends at: `192.168.4.239` — no overlap.

Planned assignments (enforced per-service via `loadBalancerIP` annotations, not here):

| IP | Service |
| ---- | --------- |
| `192.168.4.240` | Traefik (ingress entrypoint) |
| `192.168.4.241` | Pi-hole (DNS on port 53) |
| `192.168.4.242+` | Available |

---

## Apply

```bash
terraform init
terraform plan
terraform apply
```

Verify pool and advertisement were created:

```bash
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
```

Verify speakers are healthy (one per node):

```bash
kubectl get pods -n metallb-system
```

---

## Ghost State Warning

The Feb 2026 rebuild was triggered in part by corrupted MetalLB memberlist gossip state that made all three speakers think each other had failed. This is unrecoverable without a full reinstall. On a clean cluster this won't happen, but if MetalLB speakers start behaving erratically after a network partition or node failure, the fastest fix is:

```bash
# In metallb/ directory
terraform destroy
terraform apply
```

This is safe because MetalLB holds no persistent state — it re-learns the network on startup.

---

## Variables

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `chart_version` | `0.15.3` | MetalLB Helm chart version |
| `namespace` | `metallb-system` | Deployment namespace |
| `ip_pool_range` | `192.168.4.240-192.168.4.254` | LoadBalancer IP pool |
| `ip_pool_name` | `default-pool` | IPAddressPool resource name |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
