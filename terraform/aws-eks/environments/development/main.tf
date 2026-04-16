
# --- NETWORKING (Foundation) ---
# Creates the VPC and Subnets. 
module "networking" {
  source   = "../modules/networking"
  vpc_cidr = var.vpc_cidr

  # Tags allow the ALB Controller to auto-discover subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"        
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"        
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# --- EKS CLUSTER (Compute) ---
# The control plane and managed node groups.
# It depends on networking for the private subnet IDs where nodes will live.
module "eks" {
  source             = "./modules/eks"

  cluster_name       = var.cluster_name
  region             = var.aws_region
  namespace          = var.namespace
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  # Tags: autoscaler uses them to "discover" which groups it is allowed to scale
  eks_node_group_tags = {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  }

  # Ensure these variables are passed to enable auto-scaling logic in nodes
  desired_size       = var.desired_size
  max_size           = var.max_size
  min_size           = var.min_size
}

# --- WAF (Security) ---
# Creates the firewall rules. 
# We will use the output of this module (WAF ARN) as an annotation in our Ingress.
module "waf" {
  source         = "./modules/waf"
  name           = "${var.cluster_name}-waf"
  scope          = "REGIONAL" 
}

# --- ALB CONTROLLER (Ingress Driver) ---
# The logic that watches Kubernetes Ingress resources and creates AWS ALBs.
# Needs OIDC from EKS to perform IAM actions (IRSA).
module "alb_controller" {
  source = "./modules/alb-controller"

  region            = var.aws_region
  cluster_name      = module.eks.cluster_name
  vpc_id            = module.networking.vpc_id
  namespace         = var.namespace
  oidc_provider_arn = module.eks.oidc_provider_arn

}

# ---  ARGOCD (Application Management) ---
# Deploys ArgoCD into the cluster. 
module "argocd" {
  source            = "./modules/install-argocd"

  cluster_name      = module.eks.cluster_name
  vpc_id            = module.networking.vpc_id
  namespace         = "argocd"
  
  allowed_cidr      = var.allowed_cidr 
  expose_type       = var.expose_type

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  waf_arn           = module.waf.arn 
}


# Installs the Metrics Server for HPA and Cluster Autoscaler for node scaling
module "eks_addons" {
  source            = "./modules/eks-addons"
  cluster_name      = module.eks.cluster_name
  region            = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn
}





