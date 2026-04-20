
# ============================================================================
# TERRAFORM DEPLOYMENT FOR ARGOCD RESOURCES
# This script deploys the Argo Projects first, then the ApplicationSet.
# ============================================================================

# Fetch AWS resource IDs from the existing Infrastructure state
data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    # Using abspath ensures the backend finds the file regardless of execution context
    path = abspath("${path.module}/../eks-infra/terraform.tfstate")
  }
}

# Deploy Development Project
resource "kubernetes_manifest" "dev_project" {
  manifest = yamldecode(file("${var.appset_dir}/dev-apps-project.yaml"))
}

# Deploy Production Project
resource "kubernetes_manifest" "prod_project" {
  manifest = yamldecode(file("${var.appset_dir}/prod-apps-project.yaml"))
}

# Deploy ApplicationSet (The Matrix Generator File)
# The 'depends_on' ensures projects exist before automation tries to use them.
resource "kubernetes_manifest" "nodejs_appset" {
  depends_on = [
    kubernetes_manifest.dev_project,
    kubernetes_manifest.prod_project
  ]
  manifest = yamldecode(file("${var.appset_dir}/applicationset-root.yaml"))
}

