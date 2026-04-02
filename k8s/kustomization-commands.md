

<!-- Initialization -->
  # Automatically creates a kustomization.yaml file in the current directory by detecting all existing Kubernetes manifest files
    # Use: 
      kustomize create --autodetect k8s/namespaces

<!-- Manifest Preview & Debugging -->
  # Dry Run: To see the final YAML that will be generated without actually deploying it
    # Using kubectl (Built-in) :
      kubectl kustomize apps/nodejs-app/overlays/prod
      kubectl kustomize apps/nodejs-app/overlays/dev
      OR Using Standalone CLIs
      kustomize build apps/nodejs-app/overlays/dev
  
  # Compares the locally generated Kustomize output with the resources currently running in your cluster, helping you spot unintended changes
    # Use:
      kubectl diff -k <dir>

<!-- Run this command from the root of your project to apply   -->
kubectl apply -k apps/nodejs-app/overlays/dev

# Run this command to apply the prod specific configurations: 
  kubectl apply -k apps/nodejs-app/overlays/prod





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



<!-- The Application Layer
Now that the monitoring "security guard" is active and the dashboards are ready, deploy your actual application. If the app has its own ServiceMonitor, the Prometheus Operator will automatically discover it. -->
kubectl apply -k k8s/apps/nodejs-app/overlays/development



















































































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


