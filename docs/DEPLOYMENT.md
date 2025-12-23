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

# Check HPA status
kubectl get hpa -n dev

# View HPA details
kubectl describe hpa url-shortener-hpa -n dev

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

## Horizontal Pod Autoscaler (HPA)

The deployment includes HPA for automatic scaling based on CPU utilization.

### Prerequisites

**Important**: HPA requires the Metrics Server to be installed:

```bash
# Install Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify installation
kubectl get deployment metrics-server -n kube-system

# Wait for it to be ready
kubectl wait --for=condition=available --timeout=60s deployment/metrics-server -n kube-system
```

### HPA Configuration per Environment

| Environment | Min Replicas | Max Replicas | Target CPU |
|------------|--------------|--------------|------------|
| dev | 2 | 6 | 75% |
| staging | 3 | 12 | 75% |
| prod | 5 | 15 | 75% |

### Monitoring HPA

```bash
# Check HPA status
kubectl get hpa -n dev

# Watch HPA in real-time
kubectl get hpa -n dev -w

# Detailed HPA information
kubectl describe hpa url-shortener-hpa -n dev

# Check current pod CPU usage
kubectl top pods -n dev
```

### Testing Autoscaling

Generate load to test HPA scaling:

```bash
# Start a load generator
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://url-shortener.dev.svc.cluster.local; done"

# In another terminal, watch the scaling
kubectl get hpa -n dev -w
kubectl get pods -n dev -w
```

### Customizing HPA

To modify HPA settings, edit the overlay's `kustomization.yaml`:

```yaml
patches:
  - target:
      kind: HorizontalPodAutoscaler
      name: url-shortener-hpa
    patch: |-
      - op: replace
        path: /spec/minReplicas
        value: 4
      - op: replace
        path: /spec/maxReplicas
        value: 20
      - op: replace
        path: /spec/targetCPUUtilizationPercentage
        value: 80
```

Then redeploy:
```bash
kubectl apply -k k8s/api/overlays/dev
```

## Best Practices

1. **Always test in dev first** before deploying to staging/prod
2. **Use version tags** for container images in production
3. **Review configuration** with `kubectl kustomize` before applying
4. **Monitor logs** during and after deployment
5. **Keep secrets secure** - consider external secret management for production
6. **Use resource limits** to prevent resource exhaustion
7. **Tag releases** in git before production deployments
8. **Monitor HPA behavior** to ensure scaling thresholds are appropriate
9. **Ensure Metrics Server is running** before deploying HPA-enabled applications
