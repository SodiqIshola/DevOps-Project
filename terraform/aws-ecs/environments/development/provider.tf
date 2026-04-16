
# --- provider.tf ---

terraform {

  required_version = ">= 1.14.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.40.0"
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
