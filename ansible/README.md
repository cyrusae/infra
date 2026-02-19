# Ansible -- Layer 1 Base OS Configuration

Handles everything below Kubernetes. Run against fresh Ubuntu Server installs.
After this playbook succeeds, nodes are ready for K3s bootstrap (Layer 2).

## Structure

```
ansible/
├── site.yml                    # Main playbook -- run this
├── group_vars/
│   └── all.yml                 # Vars for every node (github_username, dotfiles_repo, etc.)
├── inventory/
│   ├── hosts.ini               # Node inventory and groups
│   └── host_vars/
│       ├── babbage.yml         # isolcpus=3,7, node_ip, tailscale hostname
│       ├── epimetheus.yml      # node_ip, tailscale hostname
│       └── kabandha.yml        # node_ip, tailscale hostname
└── roles/
    ├── common/                 # Applied to ALL nodes
    │   ├── tasks/main.yml      # Packages, Rust, cargo tools, dotfiles, NVIDIA toolkit
    │   └── handlers/main.yml
    ├── laptop/                 # Applied to [laptops] group (Epimetheus, Kabandha)
    │   ├── tasks/main.yml      # Power management: no sleep, ignore lid/power button
    │   └── handlers/main.yml
    └── desktop/                # Applied to [desktops] group (Babbage)
        ├── tasks/main.yml      # isolcpus kernel parameter (CPU defect mitigation)
        └── handlers/main.yml
```

## Before Running

1. Update `group_vars/all.yml` with your actual GitHub username and dotfiles repo path
2. Confirm your dotfiles repo has an `nvim-server` stow package (minimal config, no LazyVim)
3. Confirm SSH access works: `ansible -i inventory/hosts.ini all -m ping`
4. Decide on Tailscale auth key strategy (see note in site.yml)

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

**apt:** zsh, git, curl, wget, chrony, mosh, ripgrep, fd-find, bat, btop, ncdu, tldr,
glances, jq, neovim, zellij, build-essential, stow, nvidia-container-toolkit

**GitHub releases:** yq, lazygit

**cargo (via rustup):** eza, zoxide, lf

**install scripts:** starship, uv

**dotfiles:** clones repo, runs stow for: zsh, starship, git, zellij, lf, nvim-server

## Known Gaps (not yet implemented)

- [ ] Storage mount (`/mnt/storage`) -- depends on drive layout per node
- [ ] K3s installation (separate playbook: site-k3s.yml)

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
