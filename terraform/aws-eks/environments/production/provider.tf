
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
      Environment = "Production"
      Project     = "Node-Fargate-OTel"
      ManagedBy   = "Terraform"
    }
  }
}
