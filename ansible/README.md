# Ansible -- Layer 1 Base OS Configuration

Handles everything below Kubernetes. Run against fresh Ubuntu Server installs.
After this playbook succeeds, nodes are ready for K3s bootstrap (Layer 2).

## Structure

### Order reference

```markdown
* site.yml
* site-k3s.yml
* inventory
* group_vars
* roles

1. common
2. laptop
3. desktop
4. babbage_quirks
5. tailscale
6. k3s_primary
7. k3s_secondary
```

### File tree

```bash
ansible/
├── site.yml                          # Layer 1: base OS (run first)
├── site-k3s.yml                      # Layer 2: K3s bootstrap (run second)
│
├── inventory/
│   ├── hosts.ini                     # node groups: desktops, laptops, k3s_servers
│   └── host_vars/
│       ├── babbage.yml               # isolcpus, node_ip, tailscale_hostname, tailscale_exit_node
│       ├── epimetheus.yml            # node_ip, tailscale_hostname
│       └── kabandha.yml              # node_ip, tailscale_hostname
│
├── group_vars/
│   └── all/
│       ├── main.yml                  # github_username, dotfiles_repo, k3s_primary_*, tailscale_subnet, etc.
│       └── vault.yml                 # ENCRYPTED: vault_tailscale_authkey (and future secrets)
│
└── roles/
    ├── common/
    │   ├── tasks/main.yml            # packages, rust, cargo tools, dotfiles, NVIDIA toolkit, chrony
    │   └── handlers/main.yml
    │
    ├── laptop/
    │   ├── tasks/main.yml            # power management: mask sleep, logind.conf, consoleblank
    │   └── handlers/main.yml
    │
    ├── desktop/
    │   ├── tasks/main.yml            # placeholder (generic desktops: Babbage, Turing)
    │   └── handlers/main.yml
    │
    ├── babbage_quirks/
    │   ├── tasks/main.yml            # isolcpus=3,7 GRUB parameter (Babbage only)
    │   └── handlers/main.yml
    │
    ├── tailscale/
    │   ├── tasks/main.yml            # install, bring up with subnet routes; exit node on Babbage
    │   └── handlers/main.yml
    │
    ├── k3s_primary/
    │   ├── tasks/main.yml            # install with cluster-init, fetch token, verify SANs
    │   └── templates/
    │       └── k3s-config.yaml.j2   # cluster-init, node-ip, tls-san, disable traefik
    │
    └── k3s_secondary/
        ├── tasks/main.yml            # join cluster using token from primary hostvars
        └── templates/
            └── k3s-config.yaml.j2   # server, token, node-ip, tls-san, disable traefik
```

## Before Running

1. Update `group_vars/all.yml` with your actual GitHub username and dotfiles repo path
2. Confirm your dotfiles repo has an `nvim-server` stow package (minimal config, no LazyVim)
3. Confirm SSH access works: `ansible -i inventory/hosts.ini all -m ping`
4. Decide on Tailscale auth key strategy (see note in site.yml)

```bash
# Before running any playbooks on a new control machine:
cd ansible/
uv venv
source .venv/bin/activate

uv pip install ansible ansible-dev-tools
uv run python -m ansible galaxy collection install -r requirements.yml -p ./collections
```

ansible-lint *will* be a miserable fuck about not being able to find its friends otherwise.

## Usage

```bash
# Full run against all nodes
ansible-playbook -i inventory/hosts.ini site.yml

# Single node
ansible-playbook -i inventory/hosts.ini site.yml --limit babbage

# Dry run (check mode)
ansible-playbook -i inventory/hosts.ini site.yml --check

# Just packages (useful for adding a new tool later)
ansible-playbook -i inventory/hosts.ini site.yml --tags packages
```

## What This Installs

**apt:** zsh, git, curl, wget, chrony, mosh, ripgrep, fd-find, bat, btop, ncdu, tldr, tmux,
glances, jq, neovim, zellij, build-essential, stow, nvidia-container-toolkit, open-iscsi, nfs-common

**GitHub releases:** yq, lazygit

**cargo (via rustup):** eza, zoxide, lf, zellij

**install scripts:** starship, uv

**dotfiles:** clones repo, runs stow for: zsh, starship, git, zellij, lf, nvim-server

## Not covered by `site.yml`

- [ ] Storage mount (`/mnt/storage`) -- depends on drive layout per node *(See below)*
- [x] K3s installation (separate playbook: site-k3s.yml)

## `mnt` issue

Each machine needs a `/mnt/storage`. This should go on the largest available drive. The question of "largest available drive" varies per individual machine and needs to be handled by hand.

After `site.yml` completes and before running `site-k3s.yml`, mount the storage drive on each node. K3s and Longhorn expect `/mnt/storage` to exist and be on the correct drive before they start.

**On each node, repeat these steps:**

First, identify which device is your storage drive:

```bash
lsblk
```

Look for the drive that isn't your OS drive. It will show up without a mountpoint. Note the device name — something like `/dev/sdb` or `/dev/nvme0n1`.

If the drive is new or was wiped, create a filesystem on it:

```bash
sudo mkfs.ext4 /dev/sdX    # replace sdX with your actual device name
```

Skip this if the drive already has a filesystem and data you want to keep.

Create the mount point:

```bash
sudo mkdir -p /mnt/storage
```

Mount it temporarily to verify it works:

```bash
sudo mount /dev/sdX /mnt/storage
df -h /mnt/storage           # should show the drive's capacity
```

Add it to `/etc/fstab` so it survives reboots:

```bash
# Get the drive's UUID (more stable than device names like /dev/sdb)
sudo blkid /dev/sdX

# Edit fstab
sudo nano /etc/fstab

# Add this line at the bottom (replace UUID with your actual value):
UUID=your-uuid-here   /mnt/storage   ext4   defaults   0   2
```

Verify fstab is correct before rebooting:

```bash
sudo mount -a    # mounts everything in fstab -- if this errors, fix fstab before continuing
```

**Node-specific notes:**

- **Babbage:** 1TB drive at `/mnt/storage`. The 4TB and 8TB drives are not yet installed.
- **Epimetheus:** 1TB drive at `/mnt/storage`
- **Kabandha:** ~500GB drive at `/mnt/storage`

Using UUID in fstab rather than the device name (`/dev/sdb`) is important — device names can change if drives are added or the boot order changes. UUID is stable.

## site-k3s.yml — Layer 2 K3s Bootstrap

Run this after `site.yml` has completed on all nodes **and** after the `/mnt/storage` mounts have been done manually on each node.

```bash
ansible-playbook -i inventory/hosts.ini site-k3s.yml --ask-vault-pass
# or
ansible-playbook -i inventory/hosts.ini site-k3s.yml --vault-password-file ~/.ansible_vault_pass
```

### What it does

Three plays run in order:

**Play 1 — Babbage (primary control plane):** Writes `config.yaml`, installs K3s with `--cluster-init` (embedded etcd, HA mode), waits for the node to reach Ready state, fetches the join token, installs `etcdctl`, and fetches the kubeconfig.

**Play 2 — Epimetheus then Kabandha (secondary control plane):** Joins each node to the cluster one at a time (`serial: 1`) using the token from Play 1. Running serially avoids etcd join race conditions.

**Play 3 — Verification (runs on Babbage):** Checks all nodes are Ready and confirms 3 voting etcd members exist.

### After it completes

The kubeconfig fetched to `~/.kube/config-babbage` will have `127.0.0.1` as the server address. Replace it with the Tailscale hostname for remote access:

```bash
sed -i 's/127.0.0.1/babbage.neon-cosmological.ts.net/' ~/.kube/config-babbage
```

Then either merge it into `~/.kube/config` or point kubectl at it directly:

```bash
export KUBECONFIG=~/.kube/config-babbage
kubectl get nodes
```

Route advertisement and exit node capability also need to be approved in the Tailscale admin console after first run — Ansible brings Tailscale up but can't approve routes on your behalf:

```text
https://login.tailscale.com/admin/machines
Machines → ... → Edit route settings → approve subnet routes + exit node (Babbage only)
```

### What comes next

Layer 3 onward is Terraform. Order matters:

1. Longhorn
2. MetalLB
3. cert-manager
4. Traefik
5. Monitoring (Prometheus, Grafana, Loki, Alertmanager)
6. Services (Pi-hole, registry, Nextcloud)
