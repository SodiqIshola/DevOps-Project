# Display the generated file paths to verify where the YAMLs were saved
output "generated_monitoring_files" {
  description = "List of Helm value files generated with the WAF ARN"
  # This list comprehension loops through the resource instances created by for_each
  value       = [for f in local_file.monitoring_aws_values : f.filename]
}

# Display the retrieved WAF ARN to confirm the remote state was read correctly
output "retrieved_waf_arn" {
  description = "The WAF ARN retrieved from the remote infra state"
  value       = data.terraform_remote_state.infra.outputs.waf_arn
}
