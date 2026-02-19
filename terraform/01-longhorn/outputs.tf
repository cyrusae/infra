output "namespace" {
  description = "Namespace Longhorn was deployed into."
  value       = helm_release.longhorn.namespace
}

output "chart_version" {
  description = "Longhorn Helm chart version deployed."
  value       = helm_release.longhorn.version
}
