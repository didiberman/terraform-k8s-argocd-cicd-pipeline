# Hetzner Cloud K3s GitOps Pipeline

This project serves as a reference implementation for a modern, GitOps-based CI/CD pipeline on **Hetzner Cloud** using **K3s**.

It demonstrates how to bootstrap a Kubernetes cluster using Terraform and manage application deployment automatically using GitHub Actions and ArgoCD.

## 🚀 Architecture

The pipeline follows a GitOps workflow where the configuration in this repository is the source of truth. Includes automated **Testing** and **Observability**.

```mermaid
flowchart LR
    subgraph Infrastructure
        tf[Terraform] -->|Provisions| hcloud[Hetzner Cloud VMs]
        script[Cloud-Init] -->|Installs| k3s[K3s Cluster]
    end

    subgraph CI ["CI: GitHub Actions"]
        push[Git Push] -->|Triggers| gh_actions[GitHub Actions]
        gh_actions -->|Run Tests| unit_tests[Unit Tests]
        unit_tests -->|Builds & Pushes| ghcr[GHCR Registry]
        ghcr -->|Updates Tag| manifest[K8s Manifests]
    end

    subgraph CD ["CD: ArgoCD"]
        manifest -.->|Watched by| argocd[ArgoCD]
        argocd -->|Syncs| k3s
        k3s -->|Verifies| probes[Health Probes]
        argocd -->|Triggers| smoke[Smoke Test Job]
    end

    subgraph Obs ["Observability"]
        prom[Prometheus] -->|Scrapes| k3s
        graf[Grafana] -->|Visualizes| prom
    end
```

## 🧪 Testing Strategy

This pipeline implements a multi-layer testing strategy:

1.  **CI Layer (Pre-Merge)**:
    *   **Unit Tests**: Run via `npm test` in GitHub Actions. Blocks the build if logic fails.
2.  **CD Layer (Deployment)**:
    *   **Health Probes**: Kubernetes `liveness` (restart if dead) and `readiness` (don't route traffic until ready) probes.
3.  **Post-Deployment Layer**:
    *   **Smoke Tests**: An ArgoCD `PostSync` hook (Job) that curls the application to verify end-to-end connectivity.

## 📊 Observability

*   **Prometheus**: Installed via `kube-prometheus-stack`. Automatically scrapes the app using `ServiceMonitor`.
*   **Grafana**: Visualization dashboards.
*   **Metrics**: Application exposes custom metrics at `/metrics` (e.g., HTTP request counts).

## 🛠 Tech Stack

-   **Cloud Provider**: [Hetzner Cloud](https://hetzner.cloud) (Cost-effective, reliable)
-   **Orchestrator**: [K3s](https://k3s.io) (Lightweight Kubernetes)
-   **Infrastructure as Code**: [Terraform](https://www.terraform.io/)
-   **CI**: [GitHub Actions](https://github.com/features/actions)
-   **CD**: [ArgoCD](https://argo-cd.readthedocs.io/)
-   **Registry**: GitHub Container Registry (ghcr.io)
-   **Application**: Node.js (Sample) with `prom-client`

## 📂 Project Structure

```text
.
├── .github/workflows/   # CI/CD Workflows (GitHub Actions)
├── infra/               # Terraform Infrastructure Code
├── k8s/                 # Kubernetes Manifests (The "GitOps" State)
├── src/                 # Application Source Code
└── Dockerfile           # App Container Definition
```

## 🏁 Getting Started

### 1. Prerequisites
-   Hetzner Cloud API Token
-   Local `terraform` and `kubectl` installed.

### 2. Provision Infrastructure
```bash
cd infra
terraform init
terraform apply
# Enter your HCloud Token when prompted
```

### 3. Deploy
1.  Push this repository to GitHub.
2.  Add your `HCLOUD_TOKEN` to GitHub Secrets (optional, used if extending CI for Infra).
3.  The **GitHub Action** will automatically build the app and update the `k8s/deployment.yaml` file with the new image tag.
4.  Install ArgoCD on your cluster and apply `k8s/argocd-app.yaml`.
