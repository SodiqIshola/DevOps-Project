################################################################################
# VPC CNI Configuration: ENI Prefix Delegation
# 
# This configuration enables ENI Prefix Delegation for the VPC CNI addon, 
# allowing nodes (especially smaller instances like t3.medium) to support 
# up to 110 pods by assigning IP address prefixes instead of single IPs.
################################################################################

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.4.0"

  name                  = "${var.cluster_name}-vpc-cni-irsa"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.this.arn
      namespace_service_accounts = ["${var.namespace}:aws-node"]
    }
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = var.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.21.1-eksbuild.7" 

  # References the IAM role created by the IRSA module above
  service_account_role_arn    = module.vpc_cni_irsa.arn

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}


################################################################################
# EKS Cluster IAM Role & Policy Attachments
#
# Defines the IAM Role and permissions required by the EKS control plane.
# These standard AWS-managed policies allow the cluster to manage networking, 
# security groups, and other essential AWS resources on your behalf.
################################################################################
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Standard AWS-managed policies required for the EKS Cluster to function correctly.
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "service_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

################################################################################
# EKS Node Group IAM Role & Worker Policies
#
# Configures the IAM Role for the worker nodes (EC2 instances). 
# These policies grant nodes the necessary permissions to register with the 
# cluster, manage networking interfaces via the VPC CNI, pull container 
# images from ECR, and allow remote management via Systems Manager (SSM).
################################################################################

# --- NODE ROLE & POLICIES ---
# Essential for EC2 instances to join the cluster and pull images.
resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { 
        Service = "ec2.amazonaws.com" 
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Grants nodes permission to talk to the EKS API, manage networking (CNI), 
# and download images from ECR.
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Allows secure remote shell access and management via AWS Systems Manager
# without needing to open SSH ports or manage SSH keys.
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


################################################################################
# OIDC Identity Provider for IAM Roles for Service Accounts (IRSA)
#
# This resource establishes trust between the EKS cluster and AWS IAM. 
# It enables pods to assume specific IAM roles, providing fine-grained 
# permissions for applications like ArgoCD, AWS Load Balancer Controller, 
# and external-dns without granting broad permissions to the entire node.
################################################################################

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com", "eks.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}


################################################################################
# EKS Cluster Control Plane
#
# Provisioning the primary EKS cluster resource. This manages the Kubernetes 
# control plane, including API server access, networking configuration for 
# subnets, and the modern Access Entry authentication system.
################################################################################
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.35"

  vpc_config {
    # Keep control plane traffic in private subnets
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    # API_AND_CONFIG_MAP allows both the new Access Entry resources and the legacy aws-auth ConfigMap.
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.service_policy
  ]
}






################################################################################
# EKS Managed Node Group & Launch Template
#
# Configures the worker nodes with a custom Launch Template to support 
# ENI Prefix Delegation (high pod density). It also defines a custom 
# Security Group to manage traffic between the nodes and the control plane, 
# ensuring secure and scalable networking.
################################################################################

# Create a Launch Template to enable the higher pod limit
resource "aws_launch_template" "eks_nodes" {
  name = "${var.cluster_name}-node-template"

  # This script runs at boot and tells EKS to ignore the standard ENI-limited pod count
  user_data = base64encode(<<-EOT
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

    --==MYBOUNDARY==
    Content-Type: text/x-shellscript; charset="us-ascii"

    #!/bin/bash
    /etc/eks/bootstrap.sh ${aws_eks_cluster.this.name} --use-max-pods false

    --==MYBOUNDARY==--
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = var.eks_node_group_tags
  }

  # Force a rolling update when the template changes
  lifecycle {
    create_before_destroy = true
  }
}

# Update the Node Group to use the Launch Template
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  # Connect the Launch Template here
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.medium"]

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_policy,
    aws_eks_addon.vpc_cni # Ensure the CNI is ready before nodes join
  ]

  tags = var.eks_node_group_tags
}

# Custom node security group used to inject specific traffic rules into the EKS-managed cluster security group.
resource "aws_security_group" "eks_nodes" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for all nodes in the EKS cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                        = "${var.cluster_name}-node-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Allow Worker Nodes to receive communication from the Cluster Control Plane.
# This uses the security group that EKS automatically creates for the cluster.
resource "aws_security_group_rule" "nodes_cluster_inbound" {
  description              = "Allow worker nodes to receive communication from the cluster control plane"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  type                     = "ingress"
}

# Allow pods on nodes to communicate with the EKS control plane (Kubelet to API)
resource "aws_security_group_rule" "nodes_to_cluster_api" {
  description              = "Allow nodes to communicate with the cluster API server"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.eks_nodes.id
  type                     = "ingress"
}


