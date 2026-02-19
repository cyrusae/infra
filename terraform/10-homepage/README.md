# homepage

Deploys Homepage dashboard at `homepage.dawnfire.casa`.

**Apply order:** Layer 5, step 3. After `../registry/` (which creates the `dawnfire` namespace).

---

## How Services Appear on the Dashboard

This setup uses **Ingress annotation discovery** rather than a static `services.yaml`. Homepage reads `gethomepage.dev/` annotations from Ingress resources across the cluster and automatically populates the dashboard.

**To add a service to the dashboard**, add these annotations to its `kubernetes_ingress_v1` resource:

```hcl
annotations = {
  "gethomepage.dev/enabled"     = "true"
  "gethomepage.dev/name"        = "My Service"
  "gethomepage.dev/description" = "What it does"
  "gethomepage.dev/group"       = "Infrastructure"   # matches a group in settings.yaml layout
  "gethomepage.dev/icon"        = "myservice.png"    # from https://github.com/walkxcode/dashboard-icons
  "gethomepage.dev/href"        = "https://myservice.dawnfire.casa"
}
```

That's it — no editing the Homepage ConfigMap needed. The service appears on next page load.

**Available groups** (defined in `settings.yaml` layout in `main.tf`):
- `Infrastructure` — Pi-hole, registry, Longhorn
- `Monitoring` — Grafana, Prometheus
- `Media` — Jellyfin, *arr stack (future)
- `Personal` — Nextcloud, personal projects

To add a new group: add it to the `layout:` section in `settings.yaml` inside the ConfigMap in `main.tf`, then `terraform apply`.

---

## Adding Widgets to Service Tiles

Some services support live status widgets (query counts, CPU usage, etc.). Add `gethomepage.dev/widget.*` annotations alongside the others:

```hcl
# Pi-hole query stats widget
"gethomepage.dev/widget.type" = "pihole"
"gethomepage.dev/widget.url"  = "http://pihole-web.pihole.svc.cluster.local"
"gethomepage.dev/widget.key"  = "your-pihole-api-key"

# Grafana widget
"gethomepage.dev/widget.type"     = "grafana"
"gethomepage.dev/widget.url"      = "http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local"
"gethomepage.dev/widget.username" = "admin"
"gethomepage.dev/widget.password" = "your-password"
```

Supported widget types: `pihole`, `grafana`, `nextcloud`, `sonarr`, `radarr`, `jellyfin`, `longhorn`, and many more. See https://gethomepage.dev/widgets/ for the full list and required fields.

---

## Editing Global Config

Global config (settings, top-bar widgets, bookmarks) lives in the `kubernetes_config_map.homepage` resource in `main.tf`.

| Config key | What it controls |
|------------|-----------------|
| `settings.yaml` | Title, theme color, group layout order |
| `widgets.yaml` | Top-bar widgets: cluster stats, clock, search bar |
| `bookmarks.yaml` | Quick-link shortcuts (Cloudflare, GitHub, Tailscale, etc.) |
| `kubernetes.yaml` | Discovery mode — keep as `mode: cluster` |
| `services.yaml` | Leave empty — services come from annotations |

**Workflow:** Edit the relevant heredoc in `main.tf` → `terraform apply` → reload the page. No pod restart needed for config changes.

---

## Apply

```bash
terraform init
terraform plan
terraform apply
```

Verify:

```bash
kubectl get pods -n dawnfire -l app.kubernetes.io/name=homepage
kubectl get ingress -n dawnfire homepage
```

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `namespace` | `dawnfire` | Deployment namespace |
| `hostname` | `homepage.dawnfire.casa` | Ingress hostname |
| `cert_issuer` | `letsencrypt-staging` | cert-manager ClusterIssuer |
| `title` | `dawnfire.casa` | Browser tab title |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
