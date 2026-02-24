# dashboards

Deploys the bedroom TV display stack:

## Note: This should be 'dash'

### TODO: Fix assumptions (do not deploy this)

- **Bedroom Display** — `display.dawnfire.casa`, pinned to Epimetheus (physically connected to bedroom TV)
- **Epimetheus Remote** — `remote.dawnfire.casa`, mobile-friendly control interface, runs anywhere

**Apply order:** Layer 5, step 5 — last module applied.

---

## ⚠️ Before You Apply: Images Must Exist

Both services use custom images built and pushed to `registry.dawnfire.casa`. Terraform deploys infrastructure only — it cannot build images. Pods will enter `ImagePullBackOff` if the images aren't in the registry first.

**Check what's in the registry:**

```bash
curl https://registry.dawnfire.casa/v2/_catalog
# Expected: {"repositories":["bedroom-display","epimetheus-remote",...]}
```

**If images are missing, build and push first:**

```bash
cd ~/projects/bedroom-display && ./deploy.sh
cd ~/projects/epimetheus-remote && ./deploy.sh
```

**If you want to deploy infrastructure before images are ready**, disable the relevant services:

```bash
# Apply with bedroom display disabled until image is ready
export TF_VAR_display_enabled=false
terraform apply

# Later, once image is pushed:
export TF_VAR_display_enabled=true
terraform apply
```

---

## Apply

```bash
terraform init
terraform plan
terraform apply
```

---

## Architecture

### Bedroom Display (pinned to Epimetheus)

The bedroom TV is physically connected to Epimetheus via HDMI. A browser running in kiosk mode on Epimetheus displays `display.dawnfire.casa`. The pod is pinned to Epimetheus via `nodeSelector: kubernetes.io/hostname: epimetheus` — if Epimetheus goes down, the pod doesn't reschedule elsewhere (there's nowhere useful for it to go).

This is intentional. The TV display is a nice-to-have. It doesn't need the same HA treatment as Pi-hole or Nextcloud.

**TV kiosk setup on Epimetheus** (Ansible layer3-epimetheus or manual):

```bash
# Install Chromium and set up kiosk autostart
sudo apt install chromium-browser
# Create autostart entry pointing to https://display.dawnfire.casa
# (see Ansible role for full setup)
```

### Epimetheus Remote

The control interface for switching display modes (morning / afternoon / evening / TV). Not pinned — runs on any node and stays accessible even when Epimetheus is down. Access from phone via `https://remote.dawnfire.casa` on local network or Tailscale.

---

## Updating Dashboard Images

When you push a new image version:

```bash
# On your dev machine:
./deploy.sh   # builds and pushes to registry.dawnfire.casa

# Rolling restart to pick up the new image (imagePullPolicy: Always):
kubectl rollout restart deployment/bedroom-display -n dashboards
kubectl rollout restart deployment/epimetheus-remote -n dashboards
```

The `imagePullPolicy: Always` on both containers ensures a rollout restart actually pulls the new image even when using the `latest` tag. Once the project matures, pin to semver tags and update `display_image_tag` / `remote_image_tag` variables instead.

---

## Variables

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `namespace` | `dashboards` | Deployment namespace |
| `registry` | `registry.dawnfire.casa` | Registry for custom images |
| `cert_issuer` | `letsencrypt-staging` | cert-manager ClusterIssuer |
| `display_enabled` | `true` | Deploy bedroom display (set false if image not ready) |
| `display_image` | `bedroom-display` | Image name in registry |
| `display_image_tag` | `latest` | Image tag |
| `display_hostname` | `display.dawnfire.casa` | Ingress hostname |
| `display_node_selector` | `epimetheus` | Node to pin bedroom display to |
| `remote_enabled` | `true` | Deploy Epimetheus Remote (set false if image not ready) |
| `remote_image` | `epimetheus-remote` | Image name in registry |
| `remote_image_tag` | `latest` | Image tag |
| `remote_hostname` | `remote.dawnfire.casa` | Ingress hostname |
| `kubeconfig_path` | `~/.kube/config` | Path to kubeconfig |
| `kubeconfig_context` | `""` | kubeconfig context (empty = current) |
