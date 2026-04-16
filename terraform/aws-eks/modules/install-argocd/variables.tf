variable "cluster_name" {
  type = string
}

variable "namespace" {
  type    = string
}

variable "create_namespace" {
  type    = bool
  default = true
}

variable "allowed_cidr" {
  description = "Restrict access to ArgoCD (if LoadBalancer)"
  type        = list(string)
}

variable "waf_arn" {
  description = "Restrict access to ArgoCD (if LoadBalancer)"
  type        = list(string)
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS will be deployed"
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "The URL of the EKS OIDC provider (without https:// prefix)"
  type        = string
}