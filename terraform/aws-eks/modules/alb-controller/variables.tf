variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster is running"
  type        = string
}

variable "region" {
  description = "AWS region where the cluster is located"
  type        = string
}

variable "namespace" {
  description = "Namespace to install the controller"
  type        = string
  default     = "kube-system"
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "The URL of the EKS OIDC provider (without https:// prefix)"
  type        = string
}
