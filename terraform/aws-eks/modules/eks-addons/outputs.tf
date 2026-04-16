
output "autoscaler_iam_role_arn" {
  description = "The ARN of the IAM role created for the Cluster Autoscaler"
  value       = module.autoscaler_irsa.arn
}

output "metrics_server_status" {
  description = "The status of the metrics server helm release"
  value       = helm_release.metrics_server.status
}
