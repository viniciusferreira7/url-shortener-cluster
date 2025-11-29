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
│       │   └── secret.yaml
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

### Environment Overlays
Each environment (dev, staging, prod) has an overlay that:
1. Sets the appropriate namespace
2. Adjusts replica counts
3. Customizes resource limits
4. Uses environment-specific container images

**Development (dev)**
- 2 replicas
- CPU: 100m/200m (request/limit)
- Memory: 64Mi/128Mi

**Staging**
- 3 replicas
- CPU: 200m/500m
- Memory: 128Mi/256Mi
- Image tag: staging

**Production**
- 5 replicas
- CPU: 500m/1000m
- Memory: 256Mi/512Mi
- Image tag: latest

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
