

# Fetch AWS resource IDs from the existing Infrastructure state
data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    # Using abspath ensures the backend finds the file regardless of execution context
    path = abspath("${path.module}/../eks-infra/terraform.tfstate")
  }
}

locals {

  # Helper to find the k8s directory relative to this file
  k8s_root = abspath("${path.module}/../../../../k8s")
}


# Deploy the ArgoCD 'AppProject'
resource "kubernetes_manifest" "argocd_project" {
  # Reading from the centralized k8s directory
  manifest = yamldecode(file("${local.k8s_root}/monitoring/argo-cd/base/monitoring-project.yaml"))
}

# Deploy the 'Root Application' (App-of-Apps)
resource "kubernetes_manifest" "root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "monitoring-patch-stack-root"
      namespace = "argocd"
    }
    spec = {
      project = "observability-project"
      source = {
        repoURL        = "https://github.com/SodiqIshola/DevOps-Project"
        targetRevision = "main"
        
        # POINT TO THE OVERLAY ROOT
        path = "k8s/monitoring/argo-cd/overlays/aws" 

        # This acts as a 'patch on top of the patch'
        kustomize = {
          commonAnnotations = {
            "alb.ingress.kubernetes.io/wafv2-acl-arn" = data.terraform_remote_state.infra.outputs.waf_arn
          }
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "monitoring"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.argocd_project]
}


