###############################################################################
# terraform/nvidia-gpu/outputs.tf
###############################################################################

output "runtime_class_name" {
  description = "RuntimeClass name to use in pod specs: runtimeClassName: nvidia"
  value       = kubernetes_runtime_class_v1.nvidia.metadata[0].name
}

output "gpu_resource_name" {
  description = "Resource name to request in pod specs: nvidia.com/gpu"
  value       = "nvidia.com/gpu"
}

output "time_slicing_replicas" {
  description = "Number of virtual GPU replicas configured per physical GPU"
  value       = var.gpu_time_slices
}

output "config_map_name" {
  description = "Name of the time-slicing ConfigMap"
  value       = kubernetes_config_map_v1.time_slicing.metadata[0].name
}
