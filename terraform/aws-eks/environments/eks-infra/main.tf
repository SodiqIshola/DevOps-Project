
# --- NETWORKING (Foundation) ---
# Creates the VPC and Subnets. 
module "networking" {
  source   = "../../../modules/networking"
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
  source             = "../../modules/eks"

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
  source         = "../../modules/aws-waf"
  cluster_name   = "${var.cluster_name}-waf"
  scope          = "REGIONAL" 
}





