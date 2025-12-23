# Architecture Overview

## Project Structure

This is a Kubernetes deployment configuration for the URL Shortener API using GitOps principles with Kustomize.

```
url-shortener-cluster/
├── docs/                    # Documentation
├── infra/                   # Infrastructure setup
│   ├── kind/
│   │   └── config.yaml      # KinD cluster configuration
│   └── scripts/
│       ├── setup.sh         # Cluster setup script
│       ├── deploy.sh        # Deployment script
│       └── cleanup.sh       # Cleanup script
│
├── k8s/                     # Kubernetes manifests
│   ├── namespaces/
│   │   └── dev.yaml         # Development namespace
│   │
│   └── api/                 # URL Shortener API
│       ├── kustomization.yaml  # Base kustomization
│       ├── base/            # Base resources
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── secret.yaml
│       │   └── hpa.yaml     # Horizontal Pod Autoscaler
│       │
│       └── overlays/        # Environment-specific overlays
│           ├── dev/
│           ├── staging/
│           └── prod/
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
- **Deployment**: 2 replicas (dev) with resource limits
- **Service**: ClusterIP service for internal routing
- **Secret**: Environment variables and credentials
- **HPA**: Horizontal Pod Autoscaler for automatic scaling based on CPU utilization (75% target)

### Environment Overlays
Each environment (dev, staging, prod) has an overlay that:
1. Sets the appropriate namespace
2. Adjusts replica counts via Kustomize replicas field
3. Customizes resource limits and images using JSON patches
4. Uses environment-specific container images

**Development (dev)**
- Base replicas: 2
- HPA range: 2-6 pods (scales based on 75% CPU utilization)
- CPU: 100m/200m (request/limit)
- Memory: 64Mi/128Mi
- Image: `30aa095`

**Staging**
- Base replicas: 3
- HPA range: 3-12 pods (scales based on 75% CPU utilization)
- CPU: 200m/500m
- Memory: 128Mi/256Mi
- Image: `30aa095`

**Production**
- Base replicas: 5
- HPA range: 5-15 pods (scales based on 75% CPU utilization)
- CPU: 500m/1000m
- Memory: 256Mi/512Mi
- Image: `30aa095`

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

- **Service Type**: ClusterIP (internal cluster access)
- **API Port**: 3333 (container)
- **Service Port**: 80 (internal routing)
- **Namespace Isolation**: Each environment in its own namespace

## Data Dependencies

- **PostgreSQL**: Database connection pooling
- **Redis**: Caching and session management
- **External Auth Service**: BETTER_AUTH_URL

All credentials are stored in Kubernetes Secrets.

## Autoscaling Architecture

The deployment implements **Horizontal Pod Autoscaling** (HPA) to handle varying load conditions:

### HPA Strategy
- **Metric**: CPU utilization (75% target across all pods)
- **Behavior**: Automatically adds or removes pods based on average CPU usage
- **Environment-specific scaling**:
  - Development: 2-6 pods
  - Staging: 3-12 pods
  - Production: 5-15 pods

### Requirements
- **Metrics Server**: Must be installed in the cluster to provide CPU/memory metrics
- **Resource requests**: Containers must define CPU requests for HPA calculations
- **Monitoring**: HPA decisions are based on average CPU usage across all pod replicas

### Benefits
- **Cost efficiency**: Scales down during low traffic periods
- **Performance**: Automatically scales up during high traffic
- **Reliability**: Maintains minimum replicas for high availability
- **Protection**: Maximum replica limits prevent resource exhaustion
