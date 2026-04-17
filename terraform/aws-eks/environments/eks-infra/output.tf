
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca" {
  value = module.eks.cluster_ca
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  value = module.eks.oidc_provider_url
}

output "vpc_id" {
  value = module.networking.vpc_id
}

output "waf_arn" {
  value = module.waf.web_acl_arn
}

output "eks_cluster_security_group_id" {
  description = "The security group ID created by EKS"
  value       = module.eks.cluster_security_group_id 
}



