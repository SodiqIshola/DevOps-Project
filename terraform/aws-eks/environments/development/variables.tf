# NETWORKING
variable "vpc_cidr" {
  default = "10.1.0.0/16"
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

# --- AWS REGION ---
variable "aws_region" {
  type        = string
  default     = "ca-central-1" 
  description = "The AWS region where all infrastructure will be deployed"
}


variable "allowed_cidr" {
  description = "Restrict access to ArgoCD (if LoadBalancer)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
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









