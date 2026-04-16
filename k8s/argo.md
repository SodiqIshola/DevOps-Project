<!-- K3d Cluster Management
This project utilizes k3d to run a local, lightweight Kubernetes cluster (k3s) 
inside Docker. Use the following commands to provision or teardown your development environment: -->

  # Create the cluster and map ports 80/443 for local Traefik ingress access
  k3d cluster create my-cluster -p "80:80@loadbalancer" -p "443:443@loadbalancer" --agents 0

  # Permanently delete the cluster and wipe all associated local data
  k3d cluster delete my-cluster


<!-- 1. Install Argo CD
First, provision the Argo CD controller into your cluster. -->

  <!-- Option 1: Standard Manifest Install
  This is the "classic" way to get the controller running. Using --server-side is a pro move—it avoids those annoying "metadata too long" errors with Kubernetes CRDs. -->

    # Create the namespace
      kubectl create namespace argocd

    # Install Argo CD
      kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.6/manifests/install.yaml

    # Wait for the rollout to finish
      kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

  <!-- Option 2: The "App-of-Apps" Bootstrap 
  Using argocd-app.yaml is the GitOps way. Instead of manually managing manifests, you tell Argo CD to manage itself. 
  Note: For this to work, your argocd-app.yaml usually needs to point to a Git repo where the Argo CD Helm chart or manifests live.  -->

    # Create the namespace
      kubectl create namespace argocd

    # Install Argo CD
      kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.3.6/manifests/install.yaml


    # Deploy the bootstrap application
      kubectl apply -f k8s/argocd-install/argocd-app.yaml


<!-- 2. Retrieve Initial Credentials
Argo CD generates a temporary admin password during the first installation.  -->

  # Extract the base64-encoded password from the secret and decode it
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

    for /f "tokens=*" %i in ('kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath^="{.data.password}"') do echo %i > pass.txt & certutil -decode pass.txt pass.out & type pass.out & del pass.txt pass.out


    $password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))




<!-- Bootstrap the Observability Stack (Root App)
Now, apply your Root Application and AppProject. This single command triggers the deployment of the entire monitoring suite (Namespaces, Prometheus, Loki, Tempo, and Alloy) based on your Git configurations.  -->

  # Apply the AppProject first to define the security boundary
    kubectl apply -f k8s/monitoring/argo-cd/monitoring-project.yaml

  # Deploy the Root Application to begin the automated sync of the stack
    kubectl apply -f k8s/monitoring/argo-cd/monitoring-stack-root.yaml

    
    export TARGET_PATH="k8s/monitoring/argo-cd/base"
    envsubst < k8s/monitoring/argo-cd/monitoring-stack-root.yaml | kubectl apply -f -


    The Local "Merge" Command
    This command mimics your Terraform logic by taking the base YAML and "injecting" your local variable into the spec.source.path field:
    
    export OVERLAY_PATH="k8s/monitoring/argo-cd/base"

    yq ".spec.source.path = \"$OVERLAY_PATH\"" k8s/monitoring/argo-cd/monitoring-stack-root.yaml | kubectl apply -f -

    Alternative: Using strenv for Safety
If your path contains special characters, use the strenv function in yq to pull the variable directly from your environment:
bash
export OVERLAY_PATH="k8s/monitoring/argo-cd/base"
yq '.spec.source.path = strenv(OVERLAY_PATH)' monitoring-stack-root.yaml | kubectl apply -f -


<!-- Access the Dashboard
Since you mapped port 8080 in your k3d command, you can use port-forwarding to reach the UI from your local browser. -->

    # Forward traffic from localhost:8080 to the Argo CD server
      kubectl port-forward svc/argocd-server -n argocd 8080:443

    NOTE: You can now log in at https://localhost:8080 using the username admin and the password retrieved in Step 2.

  NOTE: When ingress is enabled
  <!-- Enable Insecure Mode via ConfigMap:
    Apply this patch to the command parameters. This tells the Argo CD server to disable its internal TLS to avoid double tls and protocol mismatches. Let ingress handle https and keep backend traffic to simple http. -->

      kubectl patch cm argocd-cmd-params-cm -n argocd -p "{\"data\": {\"server.insecure\": \"true\"}}"

    
    <!-- Restart the server: For the changes to take effect, the argocd-server pod needs to restart: -->
      kubectl rollout restart deployment argocd-server -n argocd




<!-- Apply the Security Boundaries (AppProjects)
You must apply these first. If you try to deploy the Root Apps before the Projects exist, Argo CD will reject the Applications. -->

  # Define the boundaries for Dev and Prod workloads
    kubectl apply -f k8s/apps/nodejs-app/argo-cd/development/dev-project.yaml


    kubectl apply -f k8s/apps/nodejs-app/argo-cd/production/prod-project.yaml


<!-- 
Deploy the Root Orchestrators
These are your "App-of-Apps" masters. Once applied, they will scan your Git folders and automatically begin deploying the NodeJS microservices. -->

  # Bootstrap the Development environment
    kubectl apply -f k8s/apps/nodejs-app/argo-cd/development/dev-app-root.yaml

  # Bootstrap the Production environment
    kubectl apply -f k8s/apps/nodejs-app/argo-cd/production/prod-app-root.yaml

    # NOTE: PRODUCTION SAFETY GATE: Automated sync is disabled to require "Manual Approval." 
    # ArgoCD will not touch the production namespace until these commands are explicitly run.
      # 1. ORCHESTRATION: Tell the Root App to create the Application objects (the "Child Apps") 
      # and Projects in the cluster based on your Git manifests.
        argocd app sync prod-app-root --app-namespace argocd --grpc-web

      # 2. DEPLOYMENT: Manually trigger the actual delivery of pods and services into 
      # the production namespace. This is your "Human-in-the-loop" approval step.
        argocd app sync nodejs-app-prod --app-namespace argocd --grpc-web














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







1. Check with Argo CD CLI 
The CLI provides a high-level view of whether Argo CD even "sees" your application and if it has attempted a sync.
List all applications: Confirm your app is actually registered.
bash
argocd app list
Use code with caution.

Look for the STATUS (e.g., OutOfSync, Synced) and HEALTH (e.g., Missing, Healthy).
Get detailed status: See why it might be failing (e.g., "Permission denied" or "Git repo not found").
bash
argocd app get <your-app-name>
Use code with caution.

This command shows errors in the Conditions section at the bottom. 
Argo CD
Argo CD
 +3
2. Check with kubectl (No CLI needed) 
Since Argo CD applications are just Kubernetes Custom Resources (CRDs), you can inspect them directly:
Check the Application resource:
bash
kubectl get application -n argocd
Use code with caution.

Check for errors in the status:
bash
kubectl describe application <your-app-name> -n argocd