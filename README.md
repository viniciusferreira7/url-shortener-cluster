# URL Shortener Cluster - Kubernetes Deployment

Complete Kubernetes deployment configuration for the URL Shortener API using **Kustomize** and **kind** (Kubernetes in Docker).

## 🚀 Quick Start

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
│       │   └── secret.yaml
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

### Base Configuration
Located in `k8s/api/base/`:
- **Deployment**: Container specification and pod configuration
- **Service**: ClusterIP for internal routing (port 80 → 3333)
- **Secret**: Environment variables and credentials

### Environment Overlays
Each environment extends the base with specific customizations:

| Environment | Replicas | CPU (req/lim) | Memory (req/lim) | Image Tag |
|------------|----------|---------------|------------------|-----------|
| **dev** | 2 | 100m/200m | 64Mi/128Mi | `30aa095` |
| **staging** | 3 | 200m/500m | 128Mi/256Mi | `30aa095` |
| **prod** | 5 | 500m/1000m | 256Mi/512Mi | `30aa095` |

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

Comprehensive guides are available in the `docs/` directory:

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Design patterns, namespace organization, GitOps strategy
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Complete deployment guide with manual & script methods
- **[SECRETS.md](docs/SECRETS.md)** - Secret management, security best practices, migration path
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions

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

# Watch deployment rollout
kubectl rollout status deployment/url-shortener -n dev -w
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
