
# ==============================================================================
# METRICS SERVER HELM RELEASE
# ------------------------------------------------------------------------------
# Deploys the Metrics Server to the kube-system namespace. This component is 
# critical for the Horizontal Pod Autoscaler (HPA) to retrieve resource metrics.
# ==============================================================================
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = var.namespace
  
  # Official kubernetes-sigs repository
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"

  version    = "3.13.0"

  # Ensures the server is healthy before completing
  wait = true

  set = [
    {
      # Prioritizes InternalIP for metric scraping to avoid DNS resolution issues 
      # and ensure stable communication between the Metrics Server and worker nodes.
      name  = "args"
      value = "{--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname}"
    }
  ]



}
