variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS will be deployed"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets for worker nodes"
}


variable "desired_size" {
  type    = number
}

variable "max_size" {
  type    = number
}

variable "min_size" {
  type    = number
}

variable "namespace" {
  description = "Namespace to install the controller"
  type        = string
}

variable "eks_node_group_tags" {
  type    = map(string)
  default = {}
}


