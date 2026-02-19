# nextcloud

Deploys Nextcloud with PostgreSQL at `nextcloud.dawnfire.casa`.

**Apply order:** Layer 5, step 4. After `../homepage/`.  
**Storage:** `longhorn-critical` (3 replicas) for both data and database — this is the most important data in the cluster.

---

## First Deploy

```bash
export TF_VAR_nextcloud_admin_password="..."
export TF_VAR_db_password="..."
export TF_VAR_db_root_password="..."
terraform init
terraform plan
terraform apply
```

Nextcloud takes 2–3 minutes on first boot to initialize the database schema. The liveness probe has a generous `initial_delay_seconds = 120` to account for this. If the pod is still not ready after 5 minutes, check logs:

```bash
kubectl logs -n nextcloud -l app=nextcloud --follow
```

---

## Restoring from Backup

Before teardown, Longhorn PVC snapshots should be taken of `nextcloud-data` and `nextcloud-db`. To restore:

1. Set `restore_from_backup = true` in `terraform.tfvars`
2. `terraform apply` — creates namespace, secrets, PVCs, and services, but **does not start the Nextcloud pod**
3. Restore PVC data from Longhorn snapshot (via Longhorn UI or `kubectl`)
4. Set `restore_from_backup = false`
5. `terraform apply` again — starts the Nextcloud and DB pods

> **Pre-teardown checklist:**
> - [ ] Take Longhorn snapshot of `nextcloud-data` PVC
> - [ ] Take Longhorn snapshot of `nextcloud-db` PVC
> - [ ] Note the Nextcloud version (pin `nextcloud_admin_password` in tfvars for restore)

---

## CalDAV Setup

Nextcloud CalDAV is used by Cyrus (iOS) and Martin (Android via DAVx⁵).

**CalDAV server URL:**

```
https://nextcloud.dawnfire.casa/remote.php/dav
```

**iOS (Settings → Calendar → Accounts → Add Account → Other → Add CalDAV):**

- Server: `nextcloud.dawnfire.casa`
- Username: your Nextcloud username
- Password: your Nextcloud password

**Android (DAVx⁵):**

- Base URL: `https://nextcloud.dawnfire.casa/remote.php/dav`
- Username + password as above

**Martin's Outlook friction:** Outlook on Android doesn't support CalDAV natively. DAVx⁵ + the system calendar app is the workaround — DAVx⁵ syncs Nextcloud to the Android calendar, which Outlook can optionally read.

---

## Cloudflare Tunnel (External Access)

The Cloudflare tunnel for external Nextcloud access is **not managed by this Terraform module**. It runs as a systemd service (`cloudflared`) on Babbage and is configured separately. The tunnel routes `nextcloud.dawnfire.casa` external traffic to the cluster without exposing any ports on the home router.

Internal access (local network + Tailscale) goes through Traefik Ingress as normal.

---

## Background Cron

A `CronJob` runs `cron.php` every 5 minutes. This is required for:

- CalDAV sync reliability
- File cleanup and versioning housekeeping  
- App update notifications

Without it, calendar sync degrades within hours. The cron job uses the same image and mounts the same data PVC as the main pod, so it always runs the right version.

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `namespace` | `nextcloud` | Deployment namespace |
| `hostname` | `nextcloud.dawnfire.casa` | Ingress hostname |
| `cert_issuer` | `letsencrypt-prod` | cert-manager ClusterIssuer |
| `nextcloud_admin_password` | *(required)* | Admin account password |
| `db_password` | *(required)* | PostgreSQL Nextcloud user password |
| `db_root_password` | *(required)* | PostgreSQL superuser password |
| `data_storage_class` | `longhorn-critical` | Storage class for data PVC |
| `db_storage_class` | `longhorn-critical` | Storage class for database PVC |
| `data_storage_size` | `100Gi` | Data PVC size |
| `db_storage_size` | `5Gi` | Database PVC size |
| `restore_from_backup` | `false` | Skip pod creation during restore |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
