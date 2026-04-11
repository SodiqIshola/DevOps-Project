<!-- K3d Cluster Management
This project utilizes k3d to run a local, lightweight Kubernetes cluster (k3s) 
inside Docker. Use the following commands to provision or teardown your development environment: -->

  # Create the cluster and map ports 80/443 for local Traefik ingress access
  k3d cluster create my-cluster -p "80:80@loadbalancer" -p "443:443@loadbalancer" --agents 0

  # Permanently delete the cluster and wipe all associated local data
  k3d cluster delete my-cluster



<!-- The Foundation (Namespaces)
First, create the namespaces. This "pre-heats" the cluster so the following manifests have a valid destination to live in. -->
  kubectl apply -k k8s/namespaces


<!-- Configuration Injection (ConfigMaps)
CRITICAL STEP: We create the alloy-config, grafana-dashboards, datasource, and loki-rules FIRST.
Kustomize uses configMapGenerator to turn your raw .json and .yaml files into Kubernetes objects. By deploying these first, we ensure that when the Alloy Pod starts, its configuration is already waiting for it, preventing "MountVolume.SetUp failed" errors -->
  kubectl apply -k k8s/monitoring/grafana



<!--  MONITORING INFRASTRUCTURE (THE ENGINES)

This layer installs the core "Storage Engines": Prometheus, Loki, 
and Tempo. These act as the databases for all metrics, logs, 
and traces. 

We use 'helmCharts' here to pull the official community logic 
while keeping our custom overrides in local 'values/' files. -->

  # Validate the Helmfile: Checks syntax of helmfile.yaml
  # Ensures values files exist and Detects configuration errors.
    helmfile -f k8s\monitoring\helm\helmfile.yaml lint

  # Use helmfile to sync all your monitoring stacks (Grafana, Loki, Prometheus, etc.)
    helmfile -f k8s/monitoring/helm/helmfile.yaml apply

  # If the plugin installation is giving you too much trouble and you just want to deploy your monitoring stack, use sync instead of apply. The sync command doesn't require the diff plugin:
    helmfile -f k8s/monitoring/helm/helmfile.yaml sync


<!-- Monitoring Logic (Rules & ServiceMonitors)
Once the engines (Prometheus/Loki/Tempo) are up and their CRDs are established, apply the specific rules and monitors. This step tells the "Engines" exactly what to watch and how to alert. -->
kubectl apply -k k8s/monitoring

kubectl delete -k k8s/monitoring



<!-- The Application Layer
Now that the monitoring "security guard" is active and the dashboards are ready, deploy your actual application. If the app has its own ServiceMonitor, the Prometheus Operator will automatically discover it. -->
kubectl apply -k k8s/apps/nodejs-app/overlays/development

kubectl delete -k k8s/apps/nodejs-app/overlays/development



















































































<!-- 
  # PASS 1: Install everything. 
  # (The CRDs will install; some ServiceMonitors might report an 'error' 
  # or 'fail' if the CRD isn't ready in the exact millisecond they arrive).
    kubectl apply -k k8s/monitoring/helm --server-side --enable-helm

  # THE WAIT: Pause until the 'ServiceMonitor' definition is live in the cluster.
    kubectl wait --for condition=established --timeout=60s crd/servicemonitors.monitoring.coreos.com

  # PASS 2: Re-apply to catch any resources that failed in Pass 1.
  # This ensures Loki, Tempo, and Alloy objects are correctly linked 
  # now that the cluster "knows" what they are.
    kubectl apply -k k8s/monitoring/helm --enable-helm --server-side -->


