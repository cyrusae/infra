locals {
  alertmanager_values = yamlencode({
    alertmanager = {
      config = {
        global = {
          resolve_timeout = "5m"
        }
        route = {
          group_by       = ["alertname", "namespace"]
          group_wait     = "30s"
          group_interval = "5m"
          repeat_interval = "12h"
          receiver       = "discord"
        }
        receivers = [
          {
            name = "discord"
            discord_configs = [
              {
                webhook_url = var.discord_webhook_url
                title       = "{{ .CommonLabels.alertname }}"
                message     = "{{ range .Alerts }}{{ .Annotations.summary }}\\n{{ end }}"
              }
            ]
          }
        ]
      }
    }
  })

  custom_rules_values = yamlencode({
    additionalPrometheusRulesMap = {
      homelab-rules = {
        groups = [
          {
            name = "homelab.pihole"
            rules = [
              {
                alert  = "PiholeDown"
                expr   = "kube_deployment_status_replicas_available{namespace=\"pihole\",deployment=\"pihole\"} < 1"
                for    = "2m"
                labels = { severity = "critical" }
                annotations = {
                  summary     = "Pi-hole is down — household DNS failing"
                  description = "Pi-hole deployment has 0 available replicas for more than 2 minutes."
                }
              }
            ]
          },
          {
            name = "homelab.longhorn"
            rules = [
              {
                alert  = "LonghornVolumeActualSpaceUsedWarning"
                expr   = "(longhorn_volume_actual_size_bytes / longhorn_volume_capacity_bytes) > 0.80"
                for    = "5m"
                labels = { severity = "warning" }
                annotations = {
                  summary     = "Longhorn volume {{ $labels.volume }} is over 80% full"
                  description = "Volume {{ $labels.volume }} on node {{ $labels.node }} is {{ $value | humanizePercentage }} full."
                }
              },
              {
                alert  = "LonghornVolumeDegraded"
                expr   = "longhorn_volume_robustness == 2"
                for    = "5m"
                labels = { severity = "warning" }
                annotations = {
                  summary     = "Longhorn volume {{ $labels.volume }} is degraded"
                  description = "Volume {{ $labels.volume }} has fewer replicas than configured. Data is at risk."
                }
              }
            ]
          },
          {
            name = "homelab.certificates"
            rules = [
              {
                alert  = "CertExpiringIn14Days"
                expr   = "certmanager_certificate_expiration_timestamp_seconds - time() < 14 * 24 * 3600"
                for    = "1h"
                labels = { severity = "warning" }
                annotations = {
                  summary     = "Certificate {{ $labels.name }} expires in less than 14 days"
                  description = "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} is expiring soon. cert-manager should renew automatically — check if renewal is blocked."
                }
              }
            ]
          },
          {
            name = "homelab.etcd"
            rules = [
              {
                # etcd commit latency spiking is the early warning sign from the Feb 2026 cascade.
                # Default kube-prometheus-stack rules fire at higher thresholds — this one is tuned
                # for the homelab where any sustained latency spike is worth investigating.
                alert  = "EtcdHighCommitDurations"
                expr   = "histogram_quantile(0.99, rate(etcd_disk_backend_commit_duration_seconds_bucket[5m])) > 0.25"
                for    = "10m"
                labels = { severity = "warning" }
                annotations = {
                  summary     = "etcd commit latency elevated on {{ $labels.instance }}"
                  description = "etcd p99 commit duration is {{ $value }}s. This was an early indicator of the Feb 2026 cascade — investigate disk health on the affected node."
                }
              }
            ]
          }
        ]
      }
    }
  })
}