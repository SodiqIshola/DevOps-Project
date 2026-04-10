################################################################################
# ARGO CD ARCHITECTURE: APP-OF-APPS PATTERN
# ------------------------------------------------------------------------------
# 1. THE BOUNDARY (AppProject): dev-project.yaml
#    - Purpose: Security sandbox and resource governance.
#    - Whitelists: Restricts Git sources, target clusters, and namespaces.
#    - Controls: Defines allowed/denied K8s objects (Namespace vs Cluster).
#    - RBAC: Governs user/service account permissions within the project.
#
# 2. THE CONDUCTOR (Root App): dev-app-root.yaml
#    - Purpose: Orchestrator/Parent Application.
#    - Target: Points to the 'argocd/' folder containing child App manifests.
#    - Action: Automatically discovers and syncs multiple Child Applications.
#    - View: Provides the centralized "Tree View" for the entire environment.
#
# 3. THE WORKHORSE (Child App): dev-app.yaml
#    - Purpose: Individual microservice or workload definition.
#    - Target: Points to specific Kustomize overlays or Helm charts.
#    - Action: Maps environment-specific configs (replicas, tags) to the
#      predefined project boundaries.
################################################################################




<!-- 1. Install Argo CD
First, provision the Argo CD controller into your cluster. -->

  # Create the dedicated namespace for Argo CD
    kubectl create namespace argocd

  # Install Argo CD using the official stable manifests
  # --server-side is recommended to handle large CRDs
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  # Wait for the controller and server to be fully ready
    kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s


<!-- 2. Retrieve Initial Credentials
Argo CD generates a temporary admin password during the first installation.  -->

  # Extract the base64-encoded password from the secret and decode it
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo


<!-- Bootstrap the Observability Stack (Root App)
Now, apply your Root Application and AppProject. This single command triggers the deployment of the entire monitoring suite (Namespaces, Prometheus, Loki, Tempo, and Alloy) based on your Git configurations.  -->

  # Apply the AppProject first to define the security boundary
    kubectl apply -f monitoring-project.yaml

  # Deploy the Root Application to begin the automated sync of the stack
    kubectl apply -f monitoring-stack-root.yaml


<!-- Access the Dashboard
Since you mapped port 8080 in your k3d command, you can use port-forwarding to reach the UI from your local browser. -->

  # Forward traffic from localhost:8080 to the Argo CD server
    kubectl port-forward svc/argocd-server -n argocd 8080:443
  Use code with caution.

NOTE: You can now log in at https://localhost:8080 using the username admin and the password retrieved in Step 2.



<!-- Apply the Security Boundaries (AppProjects)
You must apply these first. If you try to deploy the Root Apps before the Projects exist, Argo CD will reject the Applications. -->

  # Define the boundaries for Dev and Prod workloads
    kubectl apply -f dev-apps-project.yaml
    kubectl apply -f prod-apps-project.yaml

<!-- 
Deploy the Root Orchestrators
These are your "App-of-Apps" masters. Once applied, they will scan your Git folders and automatically begin deploying the NodeJS microservices. -->

  # Bootstrap the Development environment
    kubectl apply -f dev-app-root.yaml

  # Bootstrap the Production environment
    kubectl apply -f prod-monitoring-root.yaml






<!-- USING INGRESS 
Disable Internal TLS in Argo CD 
By default, Argo CD forces HTTPS. For Traefik to route traffic on port 80 without a custom certificate, you must configure the Argo CD API server to run in insecure mode.  -->

  # Patch the ConfigMap to disable internal TLS redirection
    kubectl patch cm argocd-cmd-params-cm -n argocd -p '{"data": {"server.insecure": "true"}}'

  # Restart the server to apply the change
    kubectl rollout restart deployment argocd-server -n argocd

<!-- Create the Traefik Ingress Resource  -->
Apply this standard Kubernetes Ingress manifest. Since you mapped -p "80:80@loadbalancer" when creating your cluster, this will expose Argo CD at http://localhost. 

# Save as argocd-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    # Explicitly tell k3s to use the built-in Traefik controller
    kubernetes.io/ingress.class: traefik
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80

  # Apply the ingress manifest
    kubectl apply -f argocd-ingress.yaml



<!-- 1. The Deployment Command
Run this from your terminal in the directory where your file is located: -->

  # Apply the Root manifest to the cluster
  kubectl apply -f k8s/infra/monitoring/bootstrap/root.yaml


<!-- 2. Verify the Deployment
Once applied, you can check if Argo CD has picked it up using these commands: -->
  # List all Argo CD applications to see the 'root' and its 'children'
  kubectl get applications -n argocd

  # Or check the status of the specific Root app
  kubectl describe application observability-stack-root -n argocd

<!-- TROUBLESHOOTING
Identify the "Stuck" Resource
First, find out which specific part of the application is failing: -->

  # Get the status of all resources managed by the app
  argocd app get <child-app-name>


<!-- Check the Kubernetes Events
If a Pod isn't starting, the best place to look is the Events in the target namespace: -->
  # Example: Check why Loki isn't starting in the monitoring namespace
  kubectl get events -n monitoring --sort-by='.lastTimestamp'

Common "Stuck" Scenarios & Fixes
Scenario	          Typical Cause	        Fix
ImagePullBackOff	Wrong image name or private registry credentials missing.	Check your values.yaml for the correct image/tag.

CrashLoopBackOff	App is crashing (e.g., Alloy can't find its .alloy config file).	Check logs: kubectl logs <pod-name> -n monitoring.

Pending (PVC)	The Cloud/Cluster doesn't have the StorageClass you requested.	Check PVCs: kubectl get pvc -n monitoring.

Missing CRD	You tried to deploy a ServiceMonitor before Prometheus finished.	Ensure your Sync Waves are set correctly (CRDs must be Wave 0).


<!--  Force a Refresh/Sync
Sometimes Argo CD just needs a "nudge" if it's out of sync with the cluster: -->
  # Force a hard refresh and synchronization
  argocd app sync <child-app-name> --force --prune


<!-- Check Controller Logs
If the app doesn't show up at all, the Argo CD Application Controller might be having trouble parsing your YAML: -->
  kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller











<!-- 3. What happens next?
Argo CD detects the Root App: It reads the path you defined (e.g., k8s/monitoring/bootstrap).
Argo CD finds the Child Apps: It sees your loki.yaml, prometheus.yaml, etc., and creates them as separate Applications.
Sync Waves execute: Argo CD starts syncing the children in order: Wave 0 (Prometheus) finishes first, then it moves to Wave 1 (Loki/Tempo), and so on.
Pro-Tip: The Argo CD CLI
If you have the argocd CLI installed, you can watch the sync happen in real-time:
bash -->
  # Watch the sync progress of the root and all its children
  argocd app get observability-stack-root --watch