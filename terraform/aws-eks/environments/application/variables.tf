variable "appset_dir" {
  description = "Path to the directory containing ArgoCD manifests"
  type        = string
  default     = "../../../../k8s/apps/nodejs-app/argo-cd/appset"
}

variable "aws_region" {
  type        = string
  default     = "ca-central-1" 
  description = "The AWS region where all infrastructure will be deployed"
}