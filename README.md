# URL Shortener Cluster - Kubernetes Deployment

> ⚠️ **Work In Progress** - This project is currently under active development.

Complete Kubernetes deployment configuration for the URL Shortener API using **Kustomize** and **kind** (Kubernetes in Docker).

## 📖 Table of Contents

- [🚀 Quick Start](#-quick-start)
- [📁 Directory Structure](#-directory-structure)
- [🛠️ Technology Stack](#️-technology-stack)
- [📦 Deployment Architecture](#-deployment-architecture)
- [🚀 Deployment Commands](#-deployment-commands)
- [🔐 Secrets Management](#-secrets-management)
- [🔧 Configuration Management](#-configuration-management)
- [📚 Documentation](#-documentation)
- [🔄 Updating Deployments](#-updating-deployments)
- [🧹 Cleanup](#-cleanup)
- [🔍 Troubleshooting](#-troubleshooting)
- [📊 Resource Monitoring](#-resource-monitoring)
- [🏥 Health Probes](#-health-probes)
- [⚖️ Autoscaling with HPA V2](#️-autoscaling-with-hpa-v2)
- [🔗 Related Resources](#-related-resources)

## 🚀 Quick Start

> 📖 For detailed deployment instructions, see **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)**

### 1. Create the Cluster
```bash
bash infra/scripts/setup.sh
```

### 2. Deploy to Development
```bash
bash infra/scripts/deploy.sh dev
```

### 3. Verify Deployment
```bash
kubectl get pods -n dev
kubectl logs -f -n dev -l api=url-shortener-api
```

## 📁 Directory Structure

> 📖 See the **[📚 Documentation](#-documentation)** section below for detailed guides

```
url-shortener-cluster/
├── docs/                          # Comprehensive documentation
│   ├── ARCHITECTURE.md            # Project structure & design patterns
│   ├── DEPLOYMENT.md              # Step-by-step deployment guide
│   ├── SECRETS.md                 # Secrets management & security
│   └── TROUBLESHOOTING.md         # Common issues & solutions
│
├── infra/                         # Infrastructure & automation
│   ├── kind/
│   │   └── config.yaml            # KinD cluster configuration
│   └── scripts/
│       ├── setup.sh               # Create kind cluster
│       ├── deploy.sh              # Deploy to any environment
│       ├── test.sh                # Run stress tests with Fortio
│       └── cleanup.sh             # Delete cluster
│
├── k8s/                           # Kubernetes manifests
│   ├── namespaces/
│   │   └── dev.yaml               # Development namespace
│   │
│   └── api/                       # URL Shortener API
│       ├── kustomization.yaml     # Base kustomization
│       │
│       ├── base/                  # Base resources (all environments)
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── secret.yaml
│       │   └── hpa.yaml           # Horizontal Pod Autoscaler
│       │
│       └── overlays/              # Environment-specific customizations
│           ├── dev/               # Development
│           │   └── kustomization.yaml
│           ├── staging/           # Staging
│           │   └── kustomization.yaml
│           └── prod/              # Production
│               └── kustomization.yaml
│
└── README.md                      # This file
```

## 🛠️ Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **Kubernetes** | 1.19+ | Container orchestration |
| **kind** | Latest | Local Kubernetes in Docker |
| **Kustomize** | Built-in | Configuration management |
| **Docker** | Latest | Container runtime |
| **kubectl** | Latest | CLI for Kubernetes |

## 📦 Deployment Architecture

> 📖 For detailed architecture information, see **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**

### Base Configuration
Located in `k8s/api/base/`:
- **Deployment**: Container specification and pod configuration
  - **startupProbe**: Checks if the application has started successfully (`/api/healthz`)
  - **livenessProbe**: Restarts the container if the application becomes unresponsive (`/api/healthz`)
  - **readinessProbe**: Verifies the application is ready to accept traffic (`/api/readyz`)
- **Service**: ClusterIP for internal routing (port 80 → 3333)
- **Secret**: Environment variables and credentials
- **HPA**: Horizontal Pod Autoscaler V2 for automatic scaling based on CPU and memory utilization

### Environment Overlays
Each environment extends the base with specific customizations:

| Environment | Replicas (Base) | HPA Range | CPU (req/lim) | Memory (req/lim) | Target CPU | Target Memory | Image Tag |
|------------|----------------|-----------|---------------|------------------|------------|---------------|-----------|
| **dev** | 2 | 2-6 | 100m/200m | 64Mi/128Mi | 75% | 80% | `f74f370` |
| **staging** | 3 | 3-12 | 200m/500m | 128Mi/256Mi | 75% | 80% | `f74f370` |
| **prod** | 5 | 5-15 | 500m/1000m | 256Mi/512Mi | 75% | 80% | `f74f370` |

## 🚀 Deployment Commands

### Deploy to Specific Environment
```bash
# Development (2 replicas, minimal resources)
bash infra/scripts/deploy.sh dev

# Staging (3 replicas, medium resources)
bash infra/scripts/deploy.sh staging

# Production (5 replicas, high resources)
bash infra/scripts/deploy.sh prod
```

### Using Kustomize Directly
```bash
# Preview configuration without deploying
kubectl kustomize k8s/api/overlays/dev

# Apply to cluster
kubectl apply -k k8s/api/overlays/dev

# Dry-run to check what will be applied
kubectl apply -k k8s/api/overlays/prod --dry-run=client
```

### Verify Deployment
```bash
# Check deployments
kubectl get deployments -n dev

# Check pods
kubectl get pods -n dev -o wide

# Check services
kubectl get services -n dev

# Check HPA status
kubectl get hpa -n dev

# View HPA details
kubectl describe hpa url-shortener-hpa -n dev

# View logs
kubectl logs -f -n dev -l api=url-shortener-api

# Describe deployment
kubectl describe deployment url-shortener -n dev
```

## 🔐 Secrets Management

All environment variables are stored in `k8s/api/base/secret.yaml`:

| Variable | Purpose |
|----------|---------|
| `NODE_ENV` | Application environment (development/staging/production) |
| `PORT` | API server port (3333) |
| `CLIENT_URL` | Frontend application URL |
| `BETTER_AUTH_URL` | Authentication service endpoint |
| `DATABASE_URL` | PostgreSQL connection string |
| `DATABASE_USERNAME` | Database user credentials |
| `DATABASE_PASSWORD` | Database password |
| `DATABASE_NAME` | Database name |
| `REDIS_URL` | Redis connection string |
| `REDIS_PASSWORD` | Redis authentication |

**⚠️ Security Note**: Current secrets are base64-encoded (not encrypted). For production, use:
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- HashiCorp Vault, AWS Secrets Manager, or similar

See [docs/SECRETS.md](docs/SECRETS.md) for detailed security guidance.

## 🔧 Configuration Management

> 📖 Learn more about the architecture in **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**

### Kustomize Strategy
This project uses the **base + overlays pattern**:

1. **Base** (`k8s/api/base/`): Common resources for all environments
2. **Overlays** (`k8s/api/overlays/{env}/`): Environment-specific customizations

Benefits:
- DRY configuration (Don't Repeat Yourself)
- Single source of truth
- Easy environment-specific customization
- Scalable for additional environments

### Customizing an Environment
To customize environment-specific settings:

1. Edit `k8s/api/overlays/{env}/kustomization.yaml`
2. Update the patches section to modify resources, images, or replica counts
3. Redeploy: `bash infra/scripts/deploy.sh {env}`

Example: To change staging replicas from 3 to 4, edit the kustomization.yaml:
```yaml
replicas:
  - name: url-shortener
    count: 4  # Changed from 3
```

## 📚 Documentation

Comprehensive guides are available in the `docs/` directory. Each document provides in-depth coverage of specific aspects of the project:

### Architecture & Design
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Complete project architecture
  - Project structure and organization
  - Deployment architecture patterns
  - Kustomize base + overlays strategy
  - Network and autoscaling architecture
  - Testing and performance validation

### Deployment & Operations
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Step-by-step deployment guide
  - Prerequisites and setup instructions
  - Manual and automated deployment methods
  - Environment-specific configurations
  - HPA V2 setup and monitoring
  - Stress testing with Fortio
  - Update and rollback procedures

### Security
- **[SECRETS.md](docs/SECRETS.md)** - Secrets management guide
  - Current secrets configuration
  - Security best practices
  - Production-ready secret management
  - Migration paths to secure solutions

### Troubleshooting
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Problem-solving guide
  - Common issues and solutions
  - Cluster, deployment, and service issues
  - Performance debugging
  - Load testing and stress testing
  - Recovery procedures

## 🔄 Updating Deployments

### Update Container Image
Edit the overlay's kustomization.yaml file and update the patch section:

```bash
# Edit the kustomization file for your environment
vi k8s/api/overlays/dev/kustomization.yaml    # or staging/prod
```

Update the image value in the patches section:
```yaml
patches:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: url-shortener
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/image
        value: vinciusaf/url-shortener-api:new-tag  # Update this
```

Then redeploy:
```bash
bash infra/scripts/deploy.sh dev  # or staging/prod
```

### Scale Replicas
Edit the overlay kustomization file:
```yaml
replicas:
  - name: url-shortener
    count: 4  # Change this
```

Apply changes:
```bash
kubectl apply -k k8s/api/overlays/dev
```

### Restart Pods
```bash
kubectl rollout restart deployment/url-shortener -n dev
```

## 🧹 Cleanup

### Remove Deployment
```bash
# From specific environment
kubectl delete -k k8s/api/overlays/dev

# Delete all deployments
kubectl delete namespace dev staging prod
```

### Delete Entire Cluster
```bash
bash infra/scripts/cleanup.sh
```

## 🔍 Troubleshooting

> 📖 For comprehensive troubleshooting guidance, see **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**

### Quick Diagnostics
```bash
# Check pod status
kubectl get pods -n dev

# View pod events
kubectl describe pod POD_NAME -n dev

# Check logs
kubectl logs POD_NAME -n dev

# Check resource usage
kubectl top pods -n dev
```

For detailed troubleshooting, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## 📊 Resource Monitoring

```bash
# Monitor node resources
kubectl top nodes

# Monitor pod resources
kubectl top pods -n dev

# Watch HPA scaling behavior
kubectl get hpa -n dev -w

# Watch deployment rollout
kubectl rollout status deployment/url-shortener -n dev -w
```

## 🏥 Health Probes

The deployment includes three types of health check probes to ensure application reliability:

### Startup Probe
- **Endpoint**: `/api/healthz`
- **Purpose**: Verifies the application has started successfully
- **Configuration**:
  - Failure threshold: 3 attempts
  - Period: 10 seconds
  - Timeout: 1 second
- **Behavior**: Kubernetes waits for the startup probe to succeed before checking liveness and readiness

### Liveness Probe
- **Endpoint**: `/api/healthz`
- **Purpose**: Detects and recovers from application deadlocks or hangs
- **Configuration**:
  - Initial delay: 60 seconds (waits after container starts)
  - Failure threshold: 3 attempts
  - Period: 30 seconds
  - Timeout: 1 second
- **Behavior**: If the probe fails 3 consecutive times, Kubernetes restarts the container

### Readiness Probe
- **Endpoint**: `/api/readyz`
- **Purpose**: Determines if the pod is ready to receive traffic
- **Configuration**:
  - Failure threshold: 3 attempts
  - Period: 15 seconds
  - Timeout: 1 second
- **Behavior**: Pods failing readiness checks are removed from service endpoints

### Checking Probe Status

```bash
# View probe configuration
kubectl describe pod POD_NAME -n dev | grep -A 10 "Probes"

# Check pod readiness and restarts
kubectl get pods -n dev

# View events related to probe failures
kubectl get events -n dev --sort-by='.lastTimestamp' | grep -i probe

# Check for container restarts due to liveness probe
kubectl describe pod POD_NAME -n dev | grep -i restart
```

## ⚖️ Autoscaling with HPA V2

> 📖 For detailed HPA configuration and testing, see **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md#horizontal-pod-autoscaler-v2-hpa)**

The deployment uses Horizontal Pod Autoscaler V2 (HPA) to automatically scale pods based on CPU and memory utilization.

### HPA Configuration

| Environment | Min Replicas | Max Replicas | Target CPU | Target Memory |
|------------|--------------|--------------|------------|---------------|
| **dev** | 2 | 6 | 75% | 80% |
| **staging** | 3 | 12 | 75% | 80% |
| **prod** | 5 | 15 | 75% | 80% |

### How It Works

- HPA V2 monitors both CPU and memory utilization across all pods
- When CPU usage exceeds 75% or memory exceeds 80%, HPA scales up (adds more pods)
- When both metrics drop below their targets, HPA scales down (removes pods)
- Scaling respects the min/max replica limits for each environment

### Prerequisites

**Important**: HPA requires the Metrics Server to be installed in your cluster:

```bash
# Install Metrics Server (for kind clusters)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify Metrics Server is running
kubectl get deployment metrics-server -n kube-system
```

For kind clusters, you may need to configure the Metrics Server with specific flags. See the setup script for details.

### Monitoring Autoscaling

```bash
# Check HPA status
kubectl get hpa -n dev

# Watch real-time scaling
kubectl get hpa -n dev -w

# View detailed HPA information
kubectl describe hpa url-shortener-hpa -n dev

# Check current CPU usage
kubectl top pods -n dev
```

### Testing Autoscaling

> 📖 See **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#testing-and-performance-validation)** for testing strategy details

You can test HPA behavior using the provided stress testing script:

```bash
# Run stress test on dev environment
bash infra/scripts/test.sh dev

# Run stress test on staging
bash infra/scripts/test.sh staging

# Run stress test on prod
bash infra/scripts/test.sh prod
```

The script uses **Fortio** to generate load with environment-specific configurations:

| Environment | QPS (queries/sec) | Duration | Connections |
|------------|------------------|----------|-------------|
| **dev** | 6,000 | 120s | 100 |
| **staging** | 10,000 | 240s | 150 |
| **prod** | 1,500 | 360s | 200 |

Watch HPA scaling during the test:
```bash
# In another terminal, watch the scaling
kubectl get hpa -n dev -w
kubectl get pods -n dev -w
```

### Customizing HPA Settings

To adjust HPA V2 settings for an environment, edit the overlay's `kustomization.yaml`:

```yaml
patches:
  - target:
      kind: HorizontalPodAutoscaler
      name: url-shortener-hpa
    patch: |-
      - op: replace
        path: /spec/minReplicas
        value: 3  # Adjust minimum replicas
      - op: replace
        path: /spec/maxReplicas
        value: 10  # Adjust maximum replicas
      - op: replace
        path: /spec/metrics/0/resource/target/averageUtilization
        value: 80  # Adjust target CPU percentage
      - op: replace
        path: /spec/metrics/1/resource/target/averageUtilization
        value: 85  # Adjust target memory percentage
```

## 🔗 Related Resources

- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [kind - Kubernetes in Docker](https://kind.sigs.k8s.io/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## 📝 Project Information

- **Container Image**: `vinciusaf/url-shortener-api`
- **Service Port**: 80 (maps to container port 3333)
- **Configuration**: Kustomize-based GitOps
- **Local Dev**: kind cluster (Kubernetes in Docker)
