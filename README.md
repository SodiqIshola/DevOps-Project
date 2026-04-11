# 🚀 Node.js Observability & Security Stack

This project implements a professional **CI/CD and Observability pipeline**. It integrates **Continuous Security (Snyk)**, **Code Quality (SonarQube)**, and the full **LGTM Stack** (Loki, Grafana, Prometheus) for deep application visibility.


## 🚀 Key Features

*   **Advanced Observability**: Integrated with Prometheus (`/metrics`) and OpenTelemetry (Traces).
*   **Structured Logging**: Winston-powered logs categorized by environment and severity.
*   **Multi-Environment**: Dynamic configuration loading via environment-specific `.env` files.
*   **Dual Data Models**: Separate controllers for managing both **Tasks** and **Names**.
*   **Quality Assured**: Full Jest test suite and SonarQube integration.

---

## 🛠️ Environment Configuration

The app uses a dynamic loading system. It defaults to **development** if no variable is provided.



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

### 3. Monitoring & Metrics (`Prometheus` & `Embedded Metric Format`)
This project includes a monitoring layer designed to provide **visibility into infrastructure performance, system health, and application behavior**. The monitoring stack collects metrics from both the **host infrastructure and application layer**.

#### Prometheus
**Prometheus** acts as the central monitoring system responsible for **collecting, storing, and querying metrics**.
Key responsibilities include:
- Periodically **scraping metrics from infrastructure and services**
- Storing metrics as **time-series data**
- Enabling **alerting and dashboard visualization**
- Serving as the primary data source for monitoring tools such as **Grafana**
Prometheus follows a **pull-based model**, meaning it actively requests metrics from configured endpoints. Learn more: https://prometheus.io

#### Node Exporter
**Node Exporter** is a lightweight agent that runs on the host system and exposes **hardware and operating system metrics**. These metrics allow Prometheus to monitor **system-level performance**.
Metrics collected include:
- CPU usage  
- Memory utilization  
- Disk usage and I/O  
- Network statistics  
- System load and uptime  
Node Exporter provides insight into **host resource consumption and infrastructure health**.

#### AWS EMF (Embedded Metric Format)
**AWS Embedded Metric Format (EMF)** allows applications to **embed structured metrics directly inside CloudWatch logs**. CloudWatch automatically extracts these metrics and converts them into **CloudWatch Metrics**, enabling real-time observability.
Benefits include:
- High-cardinality application metrics  
- Real-time monitoring through **CloudWatch dashboards**  
- Simplified metric ingestion without separate metric APIs  
- Native integration with **AWS monitoring and alerting tools**

---

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
1.  **Data Sources:** Automatic connection to **Prometheus** and **Loki** and **Tempo**.
2.  **Dashboards:** Pre-loads JSON dashboards for **System Health** and **Application Logs**.

---

## 🚦 Deployment Workflow

### 1. Build & Security Scan
The environment is orchestrated using Docker Compose, ensuring a "one-command" setup. The Dockerfile executes a security scan during the build phase. While not standard for production speed, it ensures no image is pushed to `sunky24/node-task-app:latest` without a full vulnerability report.

---

### 2. Orchestration
The environment is orchestrated using **Docker Compose**, which spins up a complete **observability stack** for logs, metrics, and distributed tracing.
The following services are deployed:
- **`node-app`**: The core application service that generates **logs, metrics, and distributed traces**.
- **`promtail`**: A lightweight log collector that tails application logs and forwards them to **Loki**.
- **`loki`**: The centralized **log aggregation database** used for storing and querying application logs.
- **`prometheus`**: The **metrics database** responsible for scraping and storing time-series metrics from services and exporters.
- **`node-exporter`**: A system monitoring agent that exposes **hardware and OS-level metrics** such as CPU, memory, disk usage, and network statistics.
- **`grafana`**: The visualization and observability frontend used to build dashboards for **logs, metrics, and traces**.
- **`otel-collector`**: The **OpenTelemetry Collector** that receives, processes, and exports distributed traces from the application.
- **`tempo`**: **Grafana Tempo**, a distributed tracing backend used for storing and querying trace data.

---

### Observability Stack Overview

This stack implements the **three pillars of observability**.

| Component | Purpose |
|-----------|---------|
| **Loki + Promtail** | Centralized log aggregation |
| **Prometheus + Node Exporter** | Infrastructure and application metrics |
| **OpenTelemetry + Tempo** | Distributed tracing |


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






