# Architecture Overview

## Project Structure

This is a Kubernetes deployment configuration for the URL Shortener API using GitOps principles with Kustomize.

```
url-shortener-cluster/
├── docs/                    # Documentation
├── infra/                   # Infrastructure setup
│   ├── kind/
│   │   ├── config.yaml      # KinD cluster config (port mappings 80/443)
│   │   ├── deploy.yaml      # Nginx ingress controller manifest
│   │   └── metrics-server.yaml
│   └── scripts/
│       ├── setup.sh         # Create cluster + install ingress controller
│       ├── deploy.sh        # Deployment script
│       ├── test.sh          # Stress test script (Fortio)
│       └── cleanup.sh       # Cleanup script
│
├── k8s/                     # Kubernetes manifests
│   ├── namespaces/
│   │   └── dev.yaml         # Development namespace
│   │
│   ├── api/                 # URL Shortener API
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── secret.yaml
│   │   │   ├── hpa.yaml
│   │   │   └── ingress.yaml # Nginx Ingress (url-shortener.local)
│   │   └── overlays/
│   │       ├── dev/
│   │       ├── staging/
│   │       └── prod/
│   │
│   └── database/
│       ├── postgresql/
│       │   ├── base/        # StatefulSet, Service, Secret
│       │   └── overlays/
│       │       ├── dev/
│       │       ├── staging/
│       │       └── prod/
│       └── redis/
│           ├── base/        # StatefulSet, Service, Secret
│           └── overlays/
│               ├── dev/
│               ├── staging/
│               └── prod/
│
└── README.md                # Main documentation
```

## Technology Stack

- **Container Orchestration**: Kubernetes (K8s)
- **Local Development**: KinD (Kubernetes in Docker)
- **Configuration Management**: Kustomize
- **Infrastructure as Code**: YAML manifests
- **Container Registry**: Docker Hub

## Deployment Architecture

### Base Configuration
The `k8s/api/base/` directory contains the core resources:
- **Deployment**: 2 replicas (dev) with resource limits and health probes
  - **startupProbe**: HTTP check on `/api/healthz` (every 10s, 3 attempts max)
  - **livenessProbe**: HTTP check on `/api/healthz` (every 30s after 60s delay, 3 attempts max)
  - **readinessProbe**: HTTP check on `/api/readyz` (every 15s, 3 attempts max)
- **Service**: ClusterIP service for internal routing
- **Secret**: Environment variables and credentials
- **HPA**: Horizontal Pod Autoscaler V2 for automatic scaling based on CPU (75% target) and memory utilization (80% target)
- **Ingress**: nginx Ingress routing `url-shortener.local` → `url-shortener-service:80`

### Environment Overlays
Each environment (dev, staging, prod) has an overlay that:
1. Sets the appropriate namespace
2. Adjusts replica counts via Kustomize replicas field
3. Customizes resource limits and images using JSON patches
4. Uses environment-specific container images

**Development (dev)**
- Base replicas: 2
- HPA range: 2-6 pods (scales based on 75% CPU and 80% memory utilization)
- CPU: 100m/200m (request/limit)
- Memory: 64Mi/128Mi
- Image: `bf8b512`

**Staging**
- Base replicas: 3
- HPA range: 3-12 pods (scales based on 75% CPU and 80% memory utilization)
- CPU: 200m/500m
- Memory: 128Mi/256Mi
- Image: `bf8b512`

**Production**
- Base replicas: 5
- HPA range: 5-15 pods (scales based on 75% CPU and 80% memory utilization)
- CPU: 500m/1000m
- Memory: 256Mi/512Mi
- Image: `bf8b512`

## Kustomize Strategy

The project follows the **base + overlays pattern**:

1. **Base**: Contains common resources applicable to all environments
2. **Overlays**: Environment-specific customizations that reference the base

This approach provides:
- DRY (Don't Repeat Yourself) configuration
- Easy environment-specific customization
- Single source of truth for core resources
- Scalability for additional environments

## Network Architecture

- **External access**: nginx Ingress Controller (host: `url-shortener.local`)
- **Service Type**: ClusterIP (internal cluster routing)
- **API Port**: 3333 (container) → 80 (service) → Ingress
- **Namespace Isolation**: Each environment in its own namespace
- **kind port mappings**: host:80 → control-plane:80, host:443 → control-plane:443
- **Health Checks**:
  - **Startup probe**: `/api/healthz` - Validates application startup
  - **Liveness probe**: `/api/healthz` - Detects and restarts unhealthy containers
  - **Readiness probe**: `/api/readyz` - Controls service traffic routing

### Traffic Flow

```
curl http://url-shortener.local
  → /etc/hosts (127.0.0.1)
  → Docker port mapping (:80)
  → nginx ingress controller
  → url-shortener-service (ClusterIP :80)
  → pod (:3333)
```

## Data Dependencies

- **PostgreSQL**: StatefulSet with persistent storage, overlays per environment
- **Redis**: StatefulSet with persistent storage, overlays per environment
- **External Auth Service**: BETTER_AUTH_URL

### Database Resource Profiles

| Component | dev | staging | prod |
|-----------|-----|---------|------|
| **PostgreSQL storage** | 5Gi | 10Gi | 50Gi |
| **PostgreSQL CPU** | 500m/1 | 500m/1 | 1/2 |
| **PostgreSQL memory** | 1Gi/2Gi | 1Gi/2Gi | 2Gi/4Gi |
| **Redis storage** | 1Gi | 2Gi | 5Gi |
| **Redis CPU** | 50m/100m | 100m/250m | 250m/500m |
| **Redis memory** | 64Mi/128Mi | 128Mi/256Mi | 256Mi/512Mi |

All credentials are stored in Kubernetes Secrets.

## Autoscaling Architecture

The deployment implements **Horizontal Pod Autoscaling V2** (HPA) to handle varying load conditions:

### HPA V2 Strategy
- **Metrics**:
  - CPU utilization (75% target across all pods)
  - Memory utilization (80% target across all pods)
- **Behavior**: Automatically adds or removes pods based on average CPU and memory usage
- **Environment-specific scaling**:
  - Development: 2-6 pods
  - Staging: 3-12 pods
  - Production: 5-15 pods

### Requirements
- **Metrics Server**: Must be installed in the cluster to provide CPU/memory metrics
- **Resource requests**: Containers must define CPU and memory requests for HPA calculations
- **Monitoring**: HPA V2 decisions are based on average CPU and memory usage across all pod replicas

### Benefits
- **Cost efficiency**: Scales down during low traffic periods
- **Performance**: Automatically scales up during high traffic
- **Reliability**: Maintains minimum replicas for high availability
- **Protection**: Maximum replica limits prevent resource exhaustion
- **Multi-metric scaling**: Considers both CPU and memory for more intelligent scaling decisions

## Testing and Performance Validation

The project includes automated stress testing capabilities using **Fortio**, a load testing tool that helps validate HPA behavior and application performance.

### Stress Test Script
Location: `infra/scripts/test.sh`

The script provides environment-specific load testing:

| Environment | QPS | Duration | Connections | Purpose |
|------------|-----|----------|-------------|---------|
| **dev** | 6,000 | 120s | 100 | Basic scaling validation |
| **staging** | 10,000 | 240s | 150 | High-load scenario testing |
| **prod** | 1,500 | 360s | 200 | Long-duration stability |

### Usage
```bash
bash infra/scripts/test.sh <environment>
```

The script deploys a temporary Fortio pod in the target namespace, generates load against the URL shortener service, and automatically removes the pod after completion.

### Testing Strategy
1. **Autoscaling validation**: Verify HPA scales pods up/down based on CPU and memory metrics
2. **Performance benchmarking**: Measure response times and throughput under load
3. **Stability testing**: Ensure application remains stable during sustained traffic
4. **Resource monitoring**: Validate resource limits are appropriate for the workload
