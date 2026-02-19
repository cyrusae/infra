# infra

Ansible/Terraform infrastructure.

## Ansible

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

## Terraform

```bash
infrastructure/
└── terraform/
    │
    ├── _template/                  # Copy these when starting a new module
    │   ├── providers.tf
    │   └── variables.common.tf
    │
    │   # ── Layer 3: Core ──────────────────────────────────────────────
    │
    ├── longhorn/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── .gitignore
    │   └── README.md
    │
    ├── storage-classes/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── .gitignore
    │   └── README.md
    │
    ├── metallb/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── .gitignore
    │   └── README.md
    │
    ├── cert-manager/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── .gitignore
    │   └── README.md
    │
    ├── traefik/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── .gitignore
    │   └── README.md
    │
    │   # ── Layer 4: Monitoring ────────────────────────────────────────
    │
    ├── prometheus-grafana/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── .gitignore
    │   └── README.md
    │
    ├── loki/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── .gitignore
    │   └── README.md
    │
    │   # ── Layer 5: Services ──────────────────────────────────────────
    │
    ├── pihole/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── .gitignore
    │   └── README.md
    │
    ├── registry/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── .gitignore
    │   └── README.md
    │
    ├── homepage/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── .gitignore
    │   └── README.md
    │
    ├── nextcloud/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── .gitignore
    │   └── README.md
    │
    └── dashboards/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── providers.tf
        ├── .gitignore
        └── README.md
```
