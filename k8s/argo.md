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