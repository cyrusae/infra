# prometheus-grafana

Deploys the kube-prometheus-stack via Helm: Prometheus, Grafana, Alertmanager, node exporters, and kube-state-metrics.

**Apply order:** Layer 4, step 1. After all Layer 3 modules (longhorn, storage-classes, metallb, cert-manager, traefik).  
**Principle:** Monitoring before services. This stack must be healthy before any Layer 5 services are deployed.

---

## Secrets

Two secrets required at apply time — never committed to git:

```bash
export TF_VAR_grafana_admin_password="your-grafana-password"
export TF_VAR_discord_webhook_url="https://discord.com/api/webhooks/..."
terraform apply
```

Create a Discord webhook: Server Settings → Integrations → Webhooks → New Webhook.

---

## Apply

```bash
export TF_VAR_grafana_admin_password="..."
export TF_VAR_discord_webhook_url="..."
terraform init
terraform plan
terraform apply
```

Large chart — allow up to 10 minutes on first install. Verify:

```bash
kubectl get pods -n monitoring
kubectl get ingress -n monitoring
```

---

## Cert Issuer

`cert_issuer` defaults to `letsencrypt-staging`. Once you've confirmed Grafana and Prometheus are accessible and certs are issuing:

```bash
# Update variable and re-apply
terraform apply -var="cert_issuer=letsencrypt-prod"
```

Or set `cert_issuer = "letsencrypt-prod"` in a `terraform.tfvars` file (gitignored).

---

## Thanos Sidecar

A Thanos sidecar runs alongside Prometheus from day one. With no object store configured it operates in **no-op mode** — the StoreAPI is available but no blocks are uploaded anywhere. This costs almost nothing (one extra container) and means zero reinstall work when Garage is ready.

**When Garage is ready**, activate block uploads:

```bash
# Write objstore config (see main.tf comments for Garage example)
cat > /tmp/objstore.yml << EOF
type: S3
config:
  bucket: thanos
  endpoint: garage.dawnfire.casa:3900
  access_key: YOUR_KEY
  secret_key: YOUR_SECRET
EOF

export TF_VAR_thanos_object_store_config="$(cat /tmp/objstore.yml)"
terraform apply
```

Terraform will create the `thanos-objstore-config` secret and the sidecar will begin uploading 2-hour TSDB blocks to Garage. Historical data already on disk will be uploaded retroactively.

---

## Default Alert Rules

The kube-prometheus-stack ships with rules covering:

- Node memory/CPU/disk pressure
- Pod crash-looping and OOMKill
- PVC capacity warnings
- etcd health and latency (built-in rules, plus homelab-tuned rule below)
- Kubernetes API server and scheduler health

## Custom Homelab Rules

Additional rules defined in this module:

| Alert | Condition | Severity |
|-------|-----------|----------|
| `PiholeDown` | Pi-hole deployment has 0 replicas for 2m | critical |
| `LonghornVolumeActualSpaceUsedWarning` | Longhorn volume >80% full for 5m | warning |
| `LonghornVolumeDegraded` | Longhorn volume robustness degraded for 5m | warning |
| `CertExpiringIn14Days` | cert-manager cert expiring <14 days | warning |
| `EtcdHighCommitDurations` | etcd p99 commit latency >250ms for 10m | warning |

The etcd latency rule is tuned below the default kube-prometheus-stack threshold — it was an early indicator of the Feb 2026 cascade and worth catching sooner in a homelab context.

---

## Upgrading

kube-prometheus-stack upgrades sometimes require CRD updates before the Helm upgrade. Check release notes before bumping `chart_version`. If CRDs are out of sync:

```bash
# Check the chart's CRD directory and apply manually if needed
helm show crds prometheus-community/kube-prometheus-stack --version <new-version> | kubectl apply -f -
terraform apply
```

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `chart_version` | `69.3.2` | kube-prometheus-stack chart version |
| `namespace` | `monitoring` | Deployment namespace |
| `grafana_hostname` | `grafana.dawnfire.casa` | Grafana ingress hostname |
| `prometheus_hostname` | `prometheus.dawnfire.casa` | Prometheus ingress hostname |
| `grafana_admin_password` | *(required)* | Grafana admin password |
| `discord_webhook_url` | *(required)* | Discord webhook for Alertmanager |
| `cert_issuer` | `letsencrypt-staging` | cert-manager ClusterIssuer name |
| `grafana_storage_class` | `longhorn-duplicate` | Storage class for Grafana PVC |
| `prometheus_storage_class` | `longhorn-duplicate` | Storage class for Prometheus PVC |
| `prometheus_retention` | `30d` | Prometheus data retention |
| `prometheus_storage_size` | `20Gi` | Prometheus PVC size |
| `grafana_storage_size` | `2Gi` | Grafana PVC size |
| `thanos_sidecar_enabled` | `true` | Enable Thanos sidecar |
| `thanos_object_store_config` | `""` | Thanos objstore YAML — empty = no-op mode |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
