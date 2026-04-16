# --- AWS REGION ---
variable "aws_region" {
  type        = string
  default     = "ca-central-1" 
  description = "The AWS region where all infrastructure will be deployed"
}

variable "namespace" {
  description = "Namespace to install the controller"
  type        = string
  default     = "kube-system"
}

variable "allowed_cidr" {
  description = "Restrict access to ArgoCD (if LoadBalancer)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}