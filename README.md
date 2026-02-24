# 🚀 Node.js Observability & Security Stack

This project implements a professional **CI/CD and Observability pipeline**. It integrates **Continuous Security (Snyk)**, **Code Quality (SonarQube)**, and the full **LGTM Stack** (Loki, Grafana, Prometheus) for deep application visibility.

---

## 🏗️ System Architecture

### 1. Application & Logging (`Node.js`)
*   **Node.js Framework:** A modular service designed for high-performance task processing.
*   **Winston Logger:** Structured logging implementation using `winston.format.json()` and `winston.format.timestamp()`. This ensures all logs are machine-readable and carry consistent metadata (service name, version, and environment).
*   **Test Suite:** Integrated unit and integration tests using standard runners to ensure logic integrity before deployment.
*   **Timezone Sync:** The Node process is pinned to `America/Toronto` via `TZ` environment variables to ensure logs match the local developer environment.

### 2. Security & Quality Gates
*   **SonarQube SAST:** Automated scanning for code smells and security vulnerabilities.
*   **Snyk Container Monitor:** A [Snyk](https://snyk.io) scan is embedded in the Dockerfile. It runs `snyk monitor` during the build to track dependencies.
*   **Docker Hub:** Finalized images are pushed to [Docker Hub](https://hub.docker.com) as `24/node-app:latest`.

### 3. Monitoring & Metrics (`Prometheus`)
*   **Prometheus:** The central database that "pulls" metrics from the infrastructure.
*   **Node-Exporter:** A sidecar that collects [hardware metrics](https://prometheus.io) (CPU, Memory, Disk) from the host.

### 4. Log Aggregation (`Loki` & `Promtail`)
*   **Grafana Loki:** A highly scalable log storage system.
*   **Promtail Agent:** The shipper that tails `app.log` and handles [Pipeline Stages](https://grafana.com) to:
    *   Parse Winston JSON.
    *   Normalize timestamps to **Toronto Time**.
    *   Promote `level` to a searchable label.

---

## 📊 Visualization & Automation

### Grafana Provisioning
The stack uses **[Grafana Provisioning](https://grafana.com)** to automate the setup:
1.  **Data Sources:** Automatic connection to **Prometheus** and **Loki**.
2.  **Dashboards:** Pre-loads JSON dashboards for **System Health** and **Application Logs**.

---

## 🚦 Deployment Workflow

### 1. Build & Security Scan
The environment is orchestrated using Docker Compose, ensuring a "one-command" setup. The Dockerfile executes a security scan during the build phase. While not standard for production speed, it ensures no image is pushed to `sunky24/node-task-app:latest` without a full vulnerability report.


### 2. Orchestration
Using **Docker Compose**, the following services are spun up:
*   `node-app`: The core service.
*   `promtail`: The log collector.
*   `loki`: The log database.
*   `prometheus`: The metrics database.
*   `node-exporter`: The system metrics agent.
*   `grafana`: The visualization frontend.

---

## 🚦 Deployment & Usage

### Core CLI Commands

| Action | Command |
| :--- | :--- |
| **Build & Push** | `docker build -t node-task-app:latest . && docker tag node-task-app:latest sunky24/node-task-app:latest && docker push sunky24/node-task-app:latest` |
| **Start Stack** | `docker-compose up -d` |
| **View Logs** | `docker-compose logs -f promtail` |
| **Stop Stack** | `docker-compose down` |

### Service Endpoints

| Service | URL/Endpoint | Description |
| :--- | :--- | :--- |
| **Node Task App** | http://localhost:3000 | Access your API routes (e.g., /tasks). |
| **App Metrics** | http://localhost:3000/metrics | View raw Prometheus metrics from your app. |
| **Prometheus UI** | http://localhost:9090 | Query metrics and check Status > Targets. |
| **Grafana UI** | http://localhost:3001 | View visual dashboards (Login: admin / admin). |
| **Node Exporter** | http://localhost:9100/metrics | View raw system/hardware metrics. |
| **Loki API** | http://localhost:3100/ready | Check if the Loki log database is ready. |
| **Promtail UI** | http://localhost:9080 | Check Promtail status and active log targets. |






