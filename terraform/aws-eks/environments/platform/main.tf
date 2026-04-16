
data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "../eks-infra/terraform.tfstate"
  }
}


# --- ALB CONTROLLER (Ingress Driver) ---
# The logic that watches Kubernetes Ingress resources and creates AWS ALBs.
# Needs OIDC from EKS to perform IAM actions (IRSA).
module "alb_controller" {
  source = "../../modules/alb-controller"

  region            = var.aws_region
  cluster_name      = data.terraform_remote_state.infra.outputs.cluster_name
  vpc_id            = data.terraform_remote_state.infra.outputs.vpc_id
  namespace         = var.namespace
  oidc_provider_arn = data.terraform_remote_state.infra.outputs.oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.infra.outputs.oidc_provider_url
}

# ---  ARGOCD (Application Management) ---
# Deploys ArgoCD into the cluster.
module "argocd" {
  source = "../../modules/install-argocd"

  cluster_name      = data.terraform_remote_state.infra.outputs.cluster_name
  vpc_id            = data.terraform_remote_state.infra.outputs.vpc_id
  namespace         = "argocd"
  allowed_cidr      = var.allowed_cidr
  oidc_provider_arn = data.terraform_remote_state.infra.outputs.oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.infra.outputs.oidc_provider_url
  waf_arn           = [data.terraform_remote_state.infra.outputs.waf_arn]

  depends_on = [module.alb_controller]
}

# Installs the Metrics Server for HPA and Cluster Autoscaler for node scaling
module "eks_addons" {
  source = "../../modules/eks-addons"

  cluster_name      = data.terraform_remote_state.infra.outputs.cluster_name
  region            = var.aws_region
  namespace         = var.namespace
  oidc_provider_arn = data.terraform_remote_state.infra.outputs.oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.infra.outputs.oidc_provider_url
}


