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

- [ ] Tailscale role (needs secrets strategy decision)
- [ ] Storage mount (`/mnt/storage`) -- depends on drive layout per node
- [ ] K3s installation (separate playbook: site-k3s.yml)
