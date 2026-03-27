output "controller_name" {
  value       = "sealed-secrets-controller"
  description = "Name of the Sealed Secrets controller deployment in kube-system."
}

output "chart_version" {
  value       = helm_release.sealed_secrets.version
  description = "Deployed chart version."
}
