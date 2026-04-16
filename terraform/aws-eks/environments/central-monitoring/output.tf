
# Display the retrieved WAF ARN to confirm the remote state was read correctly
output "retrieved_waf_arn" {
  description = "The WAF ARN retrieved from the remote infra state"
  value       = data.terraform_remote_state.infra.outputs.waf_arn
}
