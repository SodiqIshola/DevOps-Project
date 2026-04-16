terraform {
  # 1. TERRAFORM VERSION
  # Using the stable version you identified
  required_version = ">= 1.14.8"

  required_providers {
    # Latest AWS Provider (Major v6.x)
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.40.0" 
    }
    # Latest Kubernetes Provider (Major v3.x)
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.1" 
    }
    # Latest Helm Provider (Major v3.x)
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.1" 
    }
    # Latest TLS Provider (v4.2.x)
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2.1"
    }
  }
}


# --- AWS PROVIDER CONFIGURATION ---
provider "aws" {
  region  = var.aws_region
  profile = "tf-project"

  # Automatically tags every resource created by this provider
  default_tags {
    tags = {
      Environment = "Development"
      Project     = "EKS-ArgoCD-Project"
      ManagedBy   = "Terraform"
    }
  }
}

# --- KUBERNETES & HELM AUTHENTICATION ---
# These data sources ensure you have a fresh token to manage cluster resources
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
















# --- provider.tf ---

terraform {
  # 1. VERSION PINNING (Crucial for team stability)
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Allows minor updates but prevents breaking changes
    }
  }
}

# 3. AWS PROVIDER CONFIGURATION
provider "aws" {
  region  = var.aws_region
  profile = "tf-project"

  # Optional: Automatically tags every resource created by this provider
  default_tags {
    tags = {
      Environment = "Development"
      Project     = "Node-Fargate-OTel"
      ManagedBy   = "Terraform"
    }
  }
}
