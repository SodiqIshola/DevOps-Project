# ==============================================================================
# IAM ROLE FOR SERVICE ACCOUNTS (IRSA) - CLUSTER AUTOSCALER
# ------------------------------------------------------------------------------
# Creates an IAM Role with the necessary permissions for the Cluster Autoscaler
# to modify EC2 Auto Scaling Groups. This role is trust-linked to the cluster's
# OIDC provider for secure, identity-based access.
# ==============================================================================
module "autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.4.0"

  name                             = "${var.cluster_name}-autoscaler-role"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [var.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      provider_url               = var.oidc_provider_url 
      namespace_service_accounts = ["${var.namespace}:cluster-autoscaler"]

      
    }
  }
}


# ==============================================================================
# KUBERNETES SERVICE ACCOUNT - CLUSTER AUTOSCALER
# ------------------------------------------------------------------------------
# Manually manages the Kubernetes ServiceAccount object. This allows for 
# cleaner lifecycle management independent of the Helm chart and explicitly 
# links the IAM Role ARN via the required EKS annotation.
# ==============================================================================
resource "kubernetes_service_account_v1" "cluster_autoscaler" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = var.namespace
    annotations = {
      # Use the iam_role_arn output from the IRSA module
      "eks.amazonaws.com/role-arn" = module.autoscaler_irsa.arn
    }
  }
}


# ==============================================================================
# CLUSTER AUTOSCALER HELM RELEASE
# ------------------------------------------------------------------------------
# Deploys the Cluster Autoscaler agent to automatically adjust the size of the AWS 
# Auto Scaling Groups based on pod resource requirements.
# ==============================================================================
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  namespace  = var.namespace
  repository = "https://kubernetes.github.io/autoscaler/"
  chart      = "cluster-autoscaler"
  version    = "9.37.0"

  values = [
    yamlencode({
      autoDiscovery = {
        clusterName = var.cluster_name
      }

      awsRegion = var.region

      rbac = {
        serviceAccount = {
          # use the account created by Terraform above
          create = false
          name   = kubernetes_service_account_v1.cluster_autoscaler.metadata[0].name
        }
      }

      extraArgs = {
        "v"                           = "4"
        "stderrthreshold"             = "info"
        "skip-nodes-with-system-pods" = "false"
        "balance-similar-node-groups" = "true"
        "expander"                    = "least-waste"
      }
    })
  ]
}
