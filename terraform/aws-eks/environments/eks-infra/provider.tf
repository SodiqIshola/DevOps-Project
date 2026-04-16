terraform {
  # 1. TERRAFORM VERSION
  # Using the stable version you identified
  required_version = ">= 1.14.6"

  required_providers {
    # Latest AWS Provider (Major v6.x)
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.40.0" 
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

