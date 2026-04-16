variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider from the EKS module"
  type        = string
}

variable "namespace" {
  description = "Namespace to install the controller"
  type        = string
}

variable "oidc_provider_url" {
  description = "The URL of the EKS OIDC provider (without https:// prefix)"
  type        = string
}
