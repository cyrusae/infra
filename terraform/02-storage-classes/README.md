# storage-classes

Defines the four Longhorn storage tiers for the dawnfire.casa cluster.

**Apply order:** Layer 3, step 2. Apply after `../longhorn/` — Longhorn CRDs must exist first.

---

## Tiers

| Class | Replicas | Binding | Data Locality | Use For |
| ------- | ---------- | --------- | --------------- | --------- |
| `longhorn-critical` | 3 (one/node) | Immediate | best-effort | etcd backups, certs, anything that must survive node loss |
| `longhorn-duplicate` | 2 | Immediate | disabled | Important but recoverable: Pi-hole config, registry data |
| `longhorn-bulk` | 1 | Immediate | disabled | Large/cheap data: media, downloads, build artifacts |
| `longhorn-sticky` | 1 | WaitForFirstConsumer | strict-local | Pod+volume affinity: dashboard state, anything node-local |

`replicas_critical` defaults to 3 — update this variable if you add always-on nodes.

---

## Apply

```bash
terraform init
terraform plan
terraform apply
```

Verify:

```bash
kubectl get storageclass
```

---

## Immutability Warning

`numberOfReplicas`, `dataLocality`, and `volumeBindingMode` are **immutable** after StorageClass creation. To change them:

1. `terraform destroy` (deletes the StorageClass resource — existing PVCs are unaffected)
2. Update the variable or parameter in `main.tf`
3. `terraform apply`

Existing PVCs retain the configuration they were created with. New PVCs pick up the updated StorageClass.

---

## Variables

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `replicas_critical` | `3` | Replicas for longhorn-critical |
| `replicas_duplicate` | `2` | Replicas for longhorn-duplicate |
| `replicas_bulk` | `1` | Replicas for longhorn-bulk |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
