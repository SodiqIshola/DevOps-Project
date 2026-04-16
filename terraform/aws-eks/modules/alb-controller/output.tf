
output "iam_role_arn" {
  description = "IAM role used by ALB controller"
  value       = module.alb_irsa.arn
}


output "service_account_name" {
  description = "Kubernetes service account name"
  value        = kubernetes_service_account_v1.alb.metadata[0].name
}

output "helm_release_status" {
  description = "Helm release status"
  value       = helm_release.alb_controller.status
}