

terraform {
  # TERRAFORM VERSION
  required_version = ">= 1.14.6"

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

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
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
# This data source ensures you have a fresh token using the name from your cluster resource
data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}

# --- KUBERNETES PROVIDER ---
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
  # Disabling the local config file ensures the provider uses the EKS data 
  # sources above rather than searching for a ~/.kube/config file on the runner.
  load_config_file       = false 
}

# --- HELM PROVIDER ---
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}




