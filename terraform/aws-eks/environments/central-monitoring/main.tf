
# Fetch AWS resource IDs from the existing Infrastructure state (e.g., EKS/WAF)
data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "../eks-infra/terraform.tfstate"
  }
}

# Define a map to loop through multiple monitoring tools and assign unique filenames
locals {
  monitoring_apps = {
    "prometheus-stack" = "prometheus-stack-aws.yaml"
    "loki"             = "loki-aws.yaml"
    "alloy"            = "alloy-aws.yaml"
    "otel-collector"   = "otel-aws.yaml"
  }
}

# Create physical YAML files on disk containing the WAF ARN retrieved from remote state
resource "local_file" "monitoring_aws_values" {
  for_each = local.monitoring_apps

  # Injects the live WAF ARN into a Kubernetes Ingress annotation snippet
  content = <<-EOT
    ingress:
      annotations:
        alb.ingress.kubernetes.io/wafv2-acl-arn: "${data.terraform_remote_state.infra.outputs.waf_arn}"
  EOT
  
  filename = "${path.root}/${var.helm_values_path}/${each.value}"

  # Validation check to ensure the WAF ARN isn't empty before writing
  lifecycle {
    precondition {
      condition     = data.terraform_remote_state.infra.outputs.waf_arn != ""
      error_message = "The WAF ARN from the infra state is empty. Check your EKS-Infra outputs."
    }
  }
}

# Deploy the ArgoCD 'AppProject' CRD to group and secure the monitoring stack
resource "kubernetes_manifest" "argocd_project" {
  manifest = yamldecode(file("${path.root}/${var.base_path}/monitoring-project.yaml"))
  depends_on = [helm_release.argocd]
}

# Deploy the 'Root Application' (App-of-Apps) and dynamically set its source path
resource "kubernetes_manifest" "root_app" {
  # Merges static YAML config with a dynamic path defined by Terraform variables
  manifest = merge(
    yamldecode(file("${path.root}/${var.base_path}/monitoring-stack-root.yaml")),
    {
      spec = {
        source = {
          path = var.overlay_path
        }
      }
    }
  )

  # Ensures the Project and generated value files exist before ArgoCD starts syncing
  depends_on = [
    kubernetes_manifest.argocd_project,
    local_file.monitoring_aws_values
  ]
}





