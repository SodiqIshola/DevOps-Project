
output "argocd_namespace" {
  value = var.namespace
}


output "argocd_helm_status" {
  value = helm_release.argocd.status
}