#!/usr/bin/env bash
# tf-inventory.sh — static inventory of Terraform-declared resources.
# Reads .tf source only. No state, no init, no cluster connection required.
#
# Usage:
#   ./tf-inventory.sh              # full inventory, one row per resource
#   ./tf-inventory.sh --census     # counts by resource type
#   ./tf-inventory.sh --by-module  # counts by module
#   ./tf-inventory.sh --crds       # kubernetes_manifest entries with kind + apiVersion
#   ./tf-inventory.sh --md         # markdown table, paste into the audit doc

set -euo pipefail
ROOT="${TF_ROOT:-terraform}"
MODE="${1:---full}"

collect() {
  find "$ROOT" -mindepth 2 -name '*.tf' -print0 \
  | xargs -0 awk '
      FNR==1 {
        n = split(FILENAME, p, "/")
        mod = p[n-1]
        file = p[n]
      }
      /^[[:space:]]*resource[[:space:]]+"/ {
        type = $2; name = $3
        gsub(/"/, "", type); gsub(/"/, "", name)
        print mod "\t" type "\t" name "\t" file
      }
    '
}

case "$MODE" in
  --census)
    collect | cut -f2 | sort | uniq -c | sort -rn
    ;;
  --by-module)
    collect | cut -f1 | sort | uniq -c | sort -rn
    ;;
  --crds)
    find "$ROOT" -mindepth 2 -name '*.tf' -print0 \
    | xargs -0 awk '
        FNR==1 { n = split(FILENAME, p, "/"); mod = p[n-1] }
        /^[[:space:]]*resource[[:space:]]+"kubernetes_manifest"/ {
          name = $3; gsub(/"/, "", name); api = ""; kind = ""; inblk = 1; next
        }
        inblk && /apiVersion[[:space:]]*=/ { api = $3; gsub(/"/, "", api) }
        inblk && /kind[[:space:]]*=/ {
          kind = $3; gsub(/"/, "", kind)
          printf "%-22s %-26s %-20s %s\n", mod, name, kind, api
          inblk = 0
        }
      '
    ;;
  --md)
    echo "| Module | Resource type | Name |"
    echo "|---|---|---|"
    collect | sort | awk -F'\t' '{ printf "| `%s` | `%s` | `%s` |\n", $1, $2, $3 }'
    ;;
  *)
    printf "%-22s %-40s %-28s %s\n" MODULE TYPE NAME FILE
    collect | sort | awk -F'\t' '{ printf "%-22s %-40s %-28s %s\n", $1, $2, $3, $4 }'
    ;;
esac
