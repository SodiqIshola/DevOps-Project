# NETWORKING
variable "vpc_cidr" {
  description = "The IP range for the VPC"
  type        = string
  default     = "10.1.0.0/16"
}


# EKS
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "namespace" {
  description = "Namespace to install the controller"
  type        = string
  default     = "kube-system"
}

variable "desired_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 3
}

variable "min_size" {
  type    = number
  default = 1
}


# --- AWS REGION ---
variable "aws_region" {
  type        = string
  default     = "ca-central-1" 
  description = "The AWS region where all infrastructure will be deployed"
}




















