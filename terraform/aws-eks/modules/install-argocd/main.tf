################################################################################
# ARGOCD INFRASTRUCTURE: HELM, IAM, SECURITY, AND NETWORKING
# 
# This configuration performs the following:
# 1. Installs ArgoCD via Helm with the built-in Ingress DISABLED.
# 2. Creates a manual Kubernetes Ingress to allow "Catch-all" access via the 
#    ALB DNS name (resolving the "://example.com" default host issue).
# 3. Sets up IRSA (IAM Roles for Service Accounts) for secure AWS integration.
# 4. Configures an AWS Security Group for strict network access control.
################################################################################

# ARGOCD HELM INSTALLATION
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
        # Link the IAM Role to the ServiceAccount (IRSA)
        serviceAccount = {
          create = true
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.argocd.arn
          }
        }

        # disable the built-in ingress to stop the chart from forcing "://example.com"
        ingress = { enabled = false }
      }

      # Runs ArgoCD in HTTP mode internally to match our ALB backend protocol
      configs = {
        params = { "server.insecure" = true }
      }
    })
  ]
}


# --- ALB INGRESS ---
# Manually creates the Ingress to allow access via the raw AWS Load Balancer URL.
resource "kubernetes_ingress_v1" "argocd_manual" {
  metadata {
    name      = "argocd-server-manual"
    namespace = var.namespace

    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/group.name"       = "platform"
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/security-groups"  = aws_security_group.argocd.id
      "alb.ingress.kubernetes.io/inbound-cidrs"    = join(",", var.allowed_cidr)
      "alb.ingress.kubernetes.io/wafv2-acl-arn"    = var.waf_arn
      
      # --- ADD THESE FOR HEALTH CHECKS ---
      # ArgoCD returns a 200 on /healthz even when unauthenticated
      "alb.ingress.kubernetes.io/healthcheck-path"             = "/healthz"
      "alb.ingress.kubernetes.io/healthcheck-protocol"         = "HTTP"
      "alb.ingress.kubernetes.io/success-codes"                = "200-399"
      "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "15"
      "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "5"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      # Leaving 'host' undefined creates a '*' rule for the ALB DNS name
      http {
        path {
          path      = "/"
          path_type = "Prefix"
  
          backend {
            service {
              name = "argocd-server"
              port { number = 80 }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
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

  # Public/Authorized Access to the Load Balancer
  ingress {
    description = "Allow HTTP traffic from users"
    from_port   = 80
    to_port     = 80
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

# --- BACKEND CONNECTIVITY (ALB TO EKS NODES) ---
# This rule bridges the network gap between the Application Load Balancer (ALB) 
# and the ArgoCD pods running on EKS. 
resource "aws_security_group_rule" "alb_to_nodes" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  description              = "Allow ArgoCD ALB to communicate with backend pods on port 8080"
  
  # The Target: The EKS-managed node security group (via remote state)
  security_group_id        = var.eks_nodes_security_group
  
  # The Source: The dedicated ArgoCD ALB security group
  source_security_group_id = aws_security_group.argocd.id
}









