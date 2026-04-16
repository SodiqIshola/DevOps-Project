############################################
# IRSA - IAM Role for Service Account
############################################
# This module creates the AWS IAM Role that the controller will USE
# It uses the official Terraform module to automatically attach the 
# AWSLoadBalancerControllerIAMPolicy required by AWS.
module "alb_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.4.0"


  name = "${var.cluster_name}-alb-controller"

  # Automatically includes the permissions to create/delete ALBs and NLBs
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      provider_url               = var.oidc_provider_url 

      # Trust Policy: Only allow the specific LBC pod in your namespace to use this role
      namespace_service_accounts = [
        "${var.namespace}:aws-load-balancer-controller"
      ]
    }
  }
}


############################################
# Kubernetes Service Account
############################################
# This creates the "Identity" inside Kubernetes.
# The annotation links this K8s account to the AWS IAM Role created above.
resource "kubernetes_service_account_v1" "alb" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = var.namespace

    annotations = {
      # Link the between K8s and AWS IAM
      "eks.amazonaws.com/role-arn" = module.alb_irsa.arn
    }
  }
}

# ==============================================================================
# AWS LOAD BALANCER CONTROLLER
# ------------------------------------------------------------------------------
# Provisions an ALB for Ingress resources and an NLB for Service resources.
# Requires a pre-existing IAM Role for Service Accounts (IRSA).
# ==============================================================================
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = var.namespace

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  version    = "1.17.1" 


  # Ensure the ServiceAccount (with the IAM link) exists before the controller starts
  depends_on = [
    kubernetes_service_account_v1.alb
  ]

  values = [
    yamlencode({
        clusterName     = var.cluster_name
        region          = var.region
        vpcId           = var.vpc_id

        # Crucial: Tell Helm NOT to create a new service account,
        # but to use the one we manually created with the IAM annotation above.
        serviceAccount  = {
            create      = false
            name        = kubernetes_service_account_v1.alb.metadata[0].name
        }
    })
  ]
}


