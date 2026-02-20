# loki

Deploys Loki (log aggregation) and Promtail (log collector DaemonSet) in single-binary mode.

**Apply order:** Layer 4, step 2. After `../prometheus-grafana/`.  
**Namespace:** Deploys into the `monitoring` namespace (created by prometheus-grafana) so Grafana can discover Loki automatically.

---

## Deployment Mode

Loki runs in **SingleBinary** (monolithic) mode — one pod handles ingestion, storage, and querying. This is the correct choice for a 3-node homelab. Simple Scalable and Microservices modes are for multi-tenant production deployments with much higher log volumes.

Promtail runs as a **DaemonSet** — one pod per node — collecting logs from all containers via the node's `/var/log` and shipping to Loki.

---

## Apply

```bash
terraform init
terraform plan
terraform apply
```

Verify:

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail
# Should show 1 loki pod and 3 promtail pods (one per node)
```

---

## Grafana Datasource

Loki should be discoverable in Grafana automatically. If not, add it manually:

- **URL:** `http://loki.monitoring.svc.cluster.local:3100`
- **Type:** Loki

In Grafana: Connections → Data Sources → Add → Loki.

---

## Storage

Loki uses `longhorn-bulk` (single replica, most available space) by default — logs are ephemeral and can be regenerated, so durability here trades off for efficiency. Adjust `storage_class` if you want more redundancy.

Default retention: 31 days (`744h`). Adjust `retention_period` to taste.

---

## Variables

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `chart_version` | `6.53.0` | Loki Helm chart version |
| `namespace` | `monitoring` | Deployment namespace (must already exist) |
| `storage_class` | `longhorn-bulk` | Storage class for Loki PVC |
| `storage_size` | `10Gi` | Loki PVC size |
| `retention_period` | `744h` | Log retention (31 days) |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
