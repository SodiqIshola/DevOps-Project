################################################################################
# EBS CSI Driver Configuration
# 
# Purpose: Enables EKS to manage EBS volumes (e.g., gp3) for Persistent Volumes.
# 1. Creates an IAM Role with EBS permissions trusted by the EKS OIDC provider.
# 2. Installs the EBS CSI Driver EKS Add-on using that IAM Role.
# 3. StorageClass: Defines the 'gp3' blueprint
################################################################################

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.4.0"

  name                             = "${var.cluster_name}-ebs-csi-controller-sa"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:ebs-csi-controller-sa"]
    }
  }
}


resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.58.0-eksbuild.1" 
  service_account_role_arn = module.ebs_csi_irsa_role.arn
  
  # Ensure the addon doesn't conflict with existing manual installs
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  
}


# The "gp3" StorageClass 
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}

