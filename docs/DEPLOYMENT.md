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

## Horizontal Pod Autoscaler V2 (HPA)

The deployment includes HPA V2 for automatic scaling based on CPU and memory utilization.

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

### HPA V2 Configuration per Environment

| Environment | Min Replicas | Max Replicas | Target CPU | Target Memory |
|------------|--------------|--------------|------------|---------------|
| dev | 2 | 6 | 75% | 80% |
| staging | 3 | 12 | 75% | 80% |
| prod | 5 | 15 | 75% | 80% |

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

#### Using the Automated Stress Test Script

The easiest way to test autoscaling is using the provided stress test script:

```bash
# Run stress test on dev environment
bash infra/scripts/test.sh dev

# Run stress test on staging
bash infra/scripts/test.sh staging

# Run stress test on prod
bash infra/scripts/test.sh prod
```

The script uses **Fortio** (a load testing tool) with environment-specific configurations:

| Environment | QPS (queries/sec) | Duration | Connections | Details |
|------------|------------------|----------|-------------|---------|
| **dev** | 6,000 | 120s | 100 | Tests basic scaling behavior |
| **staging** | 10,000 | 240s | 150 | Tests higher load scenarios |
| **prod** | 1,500 | 360s | 200 | Long-duration stability test |

During the test, monitor HPA scaling in another terminal:

```bash
# Watch HPA status
kubectl get hpa -n dev -w

# Watch pod scaling
kubectl get pods -n dev -w

# Monitor resource usage
kubectl top pods -n dev
```

#### Manual Load Testing

Alternatively, you can manually generate load:

```bash
# Start a simple load generator
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -n dev -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://url-shortener-service/; done"

# In another terminal, watch the scaling
kubectl get hpa -n dev -w
kubectl get pods -n dev -w
```

### Customizing HPA V2

To modify HPA V2 settings, edit the overlay's `kustomization.yaml`:

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
        path: /spec/metrics/0/resource/target/averageUtilization
        value: 80  # CPU target
      - op: replace
        path: /spec/metrics/1/resource/target/averageUtilization
        value: 85  # Memory target
```

Then redeploy:
```bash
kubectl apply -k k8s/api/overlays/dev
```

## Health Probes

The deployment includes three types of health check probes to ensure application reliability, proper traffic routing, and automatic recovery from failures.

### Startup Probe

The startup probe checks if the application has started successfully before the liveness and readiness probes begin.

**Configuration:**
```yaml
startupProbe:
  httpGet:
    path: /api/healthz
    port: 3333
  failureThreshold: 3
  successThreshold: 1
  timeoutSeconds: 1
  periodSeconds: 10
```

- **Endpoint**: `/api/healthz` - Application health check endpoint
- **Failure threshold**: 3 attempts (30 seconds total: 3 × 10s)
- **Period**: Checks every 10 seconds
- **Timeout**: 1 second per request

**Purpose**: Prevents liveness and readiness checks from failing during slow application startup. The container is given up to 30 seconds to start before being restarted.

### Liveness Probe

The liveness probe detects when the application is in a broken state and needs to be restarted.

**Configuration:**
```yaml
livenessProbe:
  httpGet:
    path: /api/healthz
    port: 3333
  initialDelaySeconds: 60
  failureThreshold: 3
  successThreshold: 1
  timeoutSeconds: 1
  periodSeconds: 30
```

- **Endpoint**: `/api/healthz` - Application health check endpoint
- **Initial delay**: 60 seconds (waits after container starts)
- **Failure threshold**: 3 attempts (90 seconds total: 3 × 30s)
- **Period**: Checks every 30 seconds
- **Timeout**: 1 second per request

**Purpose**: Automatically recovers from application deadlocks, hangs, or corrupted states by restarting the container. Only runs after the startup probe succeeds.

**Important**: The liveness probe uses a 30-second period to avoid unnecessary restarts during temporary issues. It waits 60 seconds after startup to allow the application to stabilize.

### Readiness Probe

The readiness probe determines if the pod is ready to receive traffic.

**Configuration:**
```yaml
readinessProbe:
  httpGet:
    path: /api/readyz
    port: 3333
  failureThreshold: 3
  successThreshold: 1
  timeoutSeconds: 1
  periodSeconds: 15
```

- **Endpoint**: `/api/readyz` - Application readiness check endpoint
- **Failure threshold**: 3 attempts (45 seconds total: 3 × 15s)
- **Period**: Checks every 15 seconds
- **Timeout**: 1 second per request

**Purpose**: Ensures only healthy pods receive traffic. If a pod fails readiness checks, it's removed from service endpoints until it becomes healthy again.

### Monitoring Probe Health

```bash
# Check pod readiness status and restart count
kubectl get pods -n dev

# View detailed probe information
kubectl describe pod POD_NAME -n dev | grep -A 10 "Probes"

# Check for probe-related events
kubectl get events -n dev --sort-by='.lastTimestamp' | grep -i probe

# View logs if probes are failing
kubectl logs POD_NAME -n dev

# Check container restart history
kubectl describe pod POD_NAME -n dev | grep -A 5 "Containers:"
```

### Troubleshooting Probe Failures

#### Startup Probe Failures

If pods are restarting repeatedly during startup:

1. **Check startup logs**:
   ```bash
   kubectl logs POD_NAME -n dev --previous
   ```

2. **Verify the application starts within 30 seconds**

3. **Check dependencies** (database, Redis) are available at startup

#### Liveness Probe Failures

If pods are restarting due to liveness probe failures:

1. **Check restart count**:
   ```bash
   kubectl get pods -n dev
   kubectl describe pod POD_NAME -n dev | grep -i restart
   ```

2. **Review logs before restart**:
   ```bash
   kubectl logs POD_NAME -n dev --previous
   ```

3. **Test the health endpoint**:
   ```bash
   kubectl port-forward POD_NAME -n dev 3333:3333
   curl http://localhost:3333/api/healthz
   ```

4. **Check for deadlocks or resource exhaustion**:
   ```bash
   kubectl top pods -n dev
   ```

**Common causes of liveness failures:**
- Application deadlocks or infinite loops
- Memory leaks causing OOM conditions
- Database connection pool exhaustion
- External dependency timeouts
- Thread starvation

#### Readiness Probe Failures

If pods are not becoming ready or receiving traffic:

1. **Check the health endpoints**:
   ```bash
   kubectl port-forward POD_NAME -n dev 3333:3333
   curl http://localhost:3333/api/healthz
   curl http://localhost:3333/api/readyz
   ```

2. **Review pod logs for errors**:
   ```bash
   kubectl logs POD_NAME -n dev
   ```

3. **Check if dependencies are available** (database, Redis, etc.)

4. **Verify service endpoints**:
   ```bash
   kubectl get endpoints url-shortener-service -n dev
   ```

## Best Practices

1. **Always test in dev first** before deploying to staging/prod
2. **Use version tags** for container images in production
3. **Review configuration** with `kubectl kustomize` before applying
4. **Monitor logs** during and after deployment
5. **Keep secrets secure** - consider external secret management for production
6. **Use resource limits** to prevent resource exhaustion
7. **Tag releases** in git before production deployments
8. **Monitor HPA V2 behavior** to ensure scaling thresholds are appropriate for both CPU and memory
9. **Ensure Metrics Server is running** before deploying HPA V2-enabled applications
10. **Monitor health probe status** to ensure pods are becoming ready and staying healthy
