# longhorn

Deploys Longhorn distributed storage via Helm.

**Apply order:** This is Layer 3, step 1. Apply before everything else.  
**Depends on:** Ansible `layer1-base` having installed `open-iscsi` and `nfs-client` on all nodes, and `layer2-k3s` having a healthy 3-node cluster.

Storage classes are **not** managed here — see `../storage-classes/`.

---

## Prerequisites (Ansible's job)

Each node must have these packages before applying:

```bash
sudo apt install open-iscsi nfs-common
sudo systemctl enable --now iscsid
```

If Longhorn manager pods are stuck in `Init` or `CrashLoopBackOff`, missing node prerequisites are the first thing to check:

```bash
kubectl get pods -n longhorn-system
kubectl describe pod -n longhorn-system <manager-pod>
```

---

## Apply

```bash
terraform init
terraform plan
terraform apply
```

Longhorn takes several minutes on first install (image pulls + CRD registration). `timeout = 600` is set; if it exceeds this on a slow connection, re-run `terraform apply` — it will pick up where it left off.

---

## After Apply

Verify all pods are healthy before proceeding to `storage-classes/`:

```bash
kubectl get pods -n longhorn-system
kubectl get daemonset -n longhorn-system
```

Expect: one `longhorn-manager` pod per node, `longhorn-driver-deployer`, `longhorn-ui`, CSI driver pods.

---

## Upgrading Longhorn

Update `chart_version` in `variables.tf` (or override via `terraform.tfvars`), then:

```bash
terraform plan   # review what changes
terraform apply
```

Longhorn upgrades are typically safe rolling upgrades. Check the Longhorn release notes for any version-specific migration steps.

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `chart_version` | `1.7.2` | Longhorn Helm chart version |
| `namespace` | `longhorn-system` | Deployment namespace |
| `replica_count` | `3` | Default replica count for Longhorn's own default storage class (not our custom tiers) |
| `storage_over_provisioning_percentage` | `200` | Over-provisioning headroom |
| `storage_minimal_available_percentage` | `10` | Refuse scheduling below this disk % |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
