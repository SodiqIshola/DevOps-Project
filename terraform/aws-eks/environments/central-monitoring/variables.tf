variable "aws_region" {
  type        = string
  default     = "ca-central-1" 
  description = "The AWS region where all infrastructure will be deployed"
}

variable "helm_values_path" {
  description = "The relative path to the directory containing Helm values files (e.g., ../k8s/monitoring/helm/values)"
  type        = string
  default     = "../k8s/monitoring/helm/values"

  validation {
    # Ensures the path doesn't end with a slash to prevent double-slashes in the filename path
    condition     = !endswith(var.helm_values_path, "/")
    error_message = "The helm_values_path should not end with a trailing slash."
  }

  validation {
    # Simple check to ensure the path looks like a directory structure
    condition     = length(split("/", var.helm_values_path)) > 1
    error_message = "The path must contain at least one directory level (e.g., folder/subfolder)."
  }
}


variable "overlay_path" {
  description = "The path to the AWS-specific kustomize overlay"
  type        = string
  default     = "k8s/monitoring/argo-cd/overlays/aws"
}

variable "base_path" {
  description = "The path to the local/base kustomize directory"
  type        = string
  default     = "../k8s/monitoring/argo-cd/base"
}







