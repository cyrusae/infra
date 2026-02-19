# Storage class names for reference in other modules.
# Since these are just strings, other modules can hardcode them —
# but outputting them here makes the canonical names discoverable.

output "critical" {
  description = "Name of the longhorn-critical storage class (3 replicas, one per node)."
  value       = kubernetes_storage_class.longhorn_critical.metadata[0].name
}

output "duplicate" {
  description = "Name of the longhorn-duplicate storage class (2 replicas, best-effort placement)."
  value       = kubernetes_storage_class.longhorn_duplicate.metadata[0].name
}

output "bulk" {
  description = "Name of the longhorn-bulk storage class (1 replica, most space available)."
  value       = kubernetes_storage_class.longhorn_bulk.metadata[0].name
}

output "sticky" {
  description = "Name of the longhorn-sticky storage class (1 replica, strict-local, WaitForFirstConsumer)."
  value       = kubernetes_storage_class.longhorn_sticky.metadata[0].name
}
