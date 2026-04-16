# Install ArgoCD via Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = var.namespace

  create_namespace = var.create_namespace
  version    = "9.5.0"


  values = [
    yamlencode({
      global ={
        image ={
          tag = "v3.3.6"
        }
      } 

      server = {
        ingress = {
          enabled = true
          ingressClassName = "alb"

          hosts = ["argocd.example.com"]

          annotations = {
            "kubernetes.io/ingress.class"           = "alb"
            # --- Security & Networking ---
            "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"

            # --- Cost Optimization (ALB Sharing) ---
            # 'group.name' allows this Ingress to share the same physical Load Balancer 
            # with other apps (like your APIs). This reduces your AWS monthly bill.
            "alb.ingress.kubernetes.io/group.name"  = "platform"

            # --- Traffic Routing ---
            # Tells the ALB to talk to ArgoCD pods over HTTPS (required for ArgoCD)
            "alb.ingress.kubernetes.io/backend-protocol" = "HTTPS"

            # Links your WAF firewall to this specific entry point
            "alb.ingress.kubernetes.io/wafv2-acl-arn" = var.waf_arn
            
            # Restricts UI access to only your authorized IP ranges
            "alb.ingress.kubernetes.io/inbound-cidrs" = join(",", var.allowed_cidr)
          }
        }
      }

      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]
}





# --- IAM ROLE (IRSA-ready foundation) ---
# This role allows the ArgoCD ServiceAccount in Kubernetes to "assume" an AWS Identity.
# It uses OIDC federation to prove the pod's identity to AWS without needing static keys.
resource "aws_iam_role" "argocd" {
  name = "${var.cluster_name}-argocd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        # The OIDC Provider is the "bridge" between EKS and AWS IAM
        Federated = var.oidc_provider_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          # Strict Security: Only allows the SPECIFIC 'argocd-server' pod 
          # in the SPECIFIC namespace to use these AWS permissions.
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.namespace}:argocd-server"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.cluster_name}-argocd-role"
    Description = "Allows ArgoCD to interact with AWS services like ECR or EKS APIs"
  }
}

# --- IAM policy (minimal safe baseline) ---
# This defines WHAT the role is allowed to do. 
# Currently, it only allows viewing cluster metadata (DescribeCluster).
resource "aws_iam_policy" "argocd" {
  name        = "${var.cluster_name}-argocd-policy"
  description = "Minimum permissions for ArgoCD to verify the EKS cluster state"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["eks:DescribeCluster"],
        Resource = "*" # Restrict this to var.cluster_arn for better security
      }
    ]
  })
}

# --- Attach policy to Role ---
# This connects the 'What' (Policy) to the 'Who' (Role).
resource "aws_iam_role_policy_attachment" "argocd" {
  role       = aws_iam_role.argocd.name
  policy_arn = aws_iam_policy.argocd.arn
}




# --- SECURITY GROUP (ONLY if LoadBalancer used) ---
# This defines the firewall rules for the ArgoCD Load Balancer.
# It controls who can reach the ArgoCD UI/API from the internet or internal network.
resource "aws_security_group" "argocd" {
  name        = "${var.cluster_name}-argocd-sg"
  description = "Controls inbound/outbound traffic for the ArgoCD Load Balancer"
  vpc_id      = var.vpc_id

  # Inbound Rules: Define who can ACCESS ArgoCD
  ingress {
    description = "Allow HTTPS traffic to the ArgoCD UI"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr 
  }

  # Outbound Rules: Define what ArgoCD can access
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # "-1" means all protocols (TCP, UDP, ICMP, etc.)
    cidr_blocks = ["0.0.0.0/0"] # Required for ArgoCD to pull charts/images from the internet
  }

  tags = {
    Name = "${var.cluster_name}-argocd-sg"
  }
}








