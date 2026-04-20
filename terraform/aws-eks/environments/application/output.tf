
# ============================================================================
# OUTPUTS
# ============================================================================
output "appset_name" {
  value = kubernetes_manifest.nodejs_appset.manifest.metadata.name
}

output "deployed_projects" {
  value = [
    kubernetes_manifest.dev_project.manifest.metadata.name,
    kubernetes_manifest.prod_project.manifest.metadata.name
  ]
}
