# Deployment Guide

## Prerequisites

- **Docker**: Installed and running
- **kind**: Kubernetes in Docker (`kind create cluster --help`)
- **kubectl**: Kubernetes CLI tool
- **kustomize**: Configuration management tool (or use `kubectl apply -k`)

## Quick Start

### 1. Create the Cluster

```bash
cd infra
bash scripts/setup.sh
```

This will:
- Create a new kind cluster named `url-shortener`
- Configure kubectl context
- Display connection information

### 2. Deploy to Development Environment

```bash
cd infra
bash scripts/deploy.sh dev
```

### 3. Verify Deployment

```bash
# Check namespace
kubectl get namespaces

# Check deployments
kubectl get deployments -n dev

# Check pods
kubectl get pods -n dev

# Check services
kubectl get services -n dev

# View pod logs
kubectl logs -n dev -l api=url-shortener-api -f
```

## Deployment to Different Environments

### Deploy to Staging

```bash
bash infra/scripts/deploy.sh staging
```

### Deploy to Production

```bash
bash infra/scripts/deploy.sh prod
```

## Manual Kustomize Application

If you prefer to apply without scripts:

### Development
```bash
kubectl apply -k k8s/api/overlays/dev
```

### Staging
```bash
kubectl apply -k k8s/api/overlays/staging
```

### Production
```bash
kubectl apply -k k8s/api/overlays/prod
```

## Viewing Configuration

To preview what will be applied without deploying:

```bash
# Dev environment
kubectl kustomize k8s/api/overlays/dev

# Staging environment
kubectl kustomize k8s/api/overlays/staging

# Production environment
kubectl kustomize k8s/api/overlays/prod
```

## Updating Deployments

### Update Image Version

Edit the overlay's `kustomization.yaml` file and update the patch section:

```bash
# Edit the kustomization for your environment
vi k8s/api/overlays/dev/kustomization.yaml    # or staging/prod
```

Update the image in the patches section:
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

Edit the respective overlay `kustomization.yaml`:

```yaml
replicas:
  - name: url-shortener
    count: 4  # Change this number
```

Apply the changes:
```bash
kubectl apply -k k8s/api/overlays/dev
```

## Troubleshooting

### Check Cluster Status
```bash
kubectl cluster-info
kubectl get nodes
```

### Inspect Pod Issues
```bash
# Describe pod
kubectl describe pod -n dev -l api=url-shortener-api

# Check logs
kubectl logs -n dev POD_NAME

# Enter pod (if available)
kubectl exec -it -n dev POD_NAME -- /bin/bash
```

### Verify Configuration
```bash
# Check applied resources
kubectl get all -n dev

# Check secrets
kubectl get secrets -n dev

# View secret values (encoded)
kubectl get secret url-shortener-secret -n dev -o yaml
```

## Cleanup

### Remove Deployment
```bash
# Dev
kubectl delete -k k8s/api/overlays/dev

# All deployments
kubectl delete namespace dev staging prod
```

### Delete Entire Cluster
```bash
bash infra/scripts/cleanup.sh
```

This will remove the kind cluster completely.

## Best Practices

1. **Always test in dev first** before deploying to staging/prod
2. **Use version tags** for container images in production
3. **Review configuration** with `kubectl kustomize` before applying
4. **Monitor logs** during and after deployment
5. **Keep secrets secure** - consider external secret management for production
6. **Use resource limits** to prevent resource exhaustion
7. **Tag releases** in git before production deployments
