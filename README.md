# Kubernetes Deployment Configuration

This directory contains Kubernetes manifests for deploying the URL Shortener API application.

## 📋 Contents

- **deployment.yml** - Kubernetes Deployment manifest for the URL Shortener API
- **secret.yml** - Kubernetes Secret manifest with environment variables and configuration

## 🚀 Overview

The Kubernetes configuration deploys the URL Shortener API as a containerized application with:
- 2 replica pods for high availability
- Resource requests and limits for optimal cluster utilization
- Secret management for sensitive environment variables
- Port 3333 exposure for API access

## 📦 Deployment Configuration

### Namespace

All resources are deployed in the `url-shortener` namespace.

### Image

The deployment uses the Docker image:
```
vinciusaf/url-shortener-api:4dacc42
```

Replace the tag with your desired version (commit SHA or version tag).

### Replicas

The deployment runs **2 replicas** for high availability and load balancing.

### Resource Management

Each pod has the following resource specifications:

**Requests** (guaranteed minimum):
- CPU: 100m (0.1 cores)
- Memory: 64Mi

**Limits** (maximum allowed):
- CPU: 200m (0.2 cores)
- Memory: 128Mi

These are conservative values suitable for a development environment. Adjust based on your actual load and cluster capacity.

## 🔐 Secrets Management

The `secret.yml` file defines a Kubernetes Secret named `url-shortener-secret` containing all required environment variables:

### Secret Data

The following variables are configured (base64 encoded):

| Variable | Purpose | Value (decoded) |
|----------|---------|-----------------|
| `NODE_ENV` | Environment | development |
| `PORT` | API Server Port | 3333 |
| `CLIENT_URL` | Frontend URL | http://localhost:3000 |
| `BETTER_AUTH_URL` | Auth Service URL | http://localhost:3333 |
| `DATABASE_URL` | PostgreSQL Connection | postgresql://localhost:5432/url_shortener |
| `DATABASE_USERNAME` | Database User | postgres |
| `DATABASE_PASSWORD` | Database Password | postgres |
| `DATABASE_NAME` | Database Name | url_shortener_pg |
| `REDIS_URL` | Redis Connection | redis://localhost:6379 |
| `REDIS_PASSWORD` | Redis Password | redis |

⚠️ **Security Warning**: These default credentials are for development only. For production:
1. Use a secrets management system (e.g., HashiCorp Vault, AWS Secrets Manager)
2. Update all passwords to strong, unique values
3. Use proper database and Redis services (not localhost)
4. Never commit secrets to version control

## 🔧 Prerequisites

- Kubernetes cluster (1.19+)
- kubectl configured with access to your cluster
- Database services (PostgreSQL and Redis) running and accessible
- The URL shortener API Docker image available in your registry

## 📥 Deployment Steps

### 1. Create the Namespace

```bash
kubectl create namespace url-shortener
```

### 2. Create the Secret

```bash
kubectl apply -f secret.yml
```

To verify:
```bash
kubectl get secrets -n url-shortener
kubectl describe secret url-shortener-secret -n url-shortener
```

### 3. Deploy the Application

```bash
kubectl apply -f deployment.yml
```

### 4. Verify the Deployment

```bash
# Check deployment status
kubectl get deployment -n url-shortener

# Check pod status
kubectl get pods -n url-shortener

# Check pod details
kubectl describe pod -n url-shortener
```

## 🔍 Monitoring and Debugging

### View Logs

```bash
# View logs from a specific pod
kubectl logs <pod-name> -n url-shortener

# View logs with timestamps
kubectl logs <pod-name> -n url-shortener --timestamps=true

# Stream logs in real-time
kubectl logs -f <pod-name> -n url-shortener
```

### Access Pod

```bash
# Execute commands in a pod
kubectl exec -it <pod-name> -n url-shortener -- /bin/sh
```

### Get Pod Details

```bash
# Detailed pod information
kubectl describe pod <pod-name> -n url-shortener

# Get pod YAML
kubectl get pod <pod-name> -n url-shortener -o yaml
```

## 🔄 Updating Deployments

### Update the Image

```bash
kubectl set image deployment/url-shortener url-shortener-api=vinciusaf/url-shortener-api:<new-tag> -n url-shortener
```

### Update Environment Variables

Edit `secret.yml` and reapply:

```bash
kubectl apply -f secret.yml
```

Then restart the pods:

```bash
kubectl rollout restart deployment/url-shortener -n url-shortener
```

### Rollback a Deployment

```bash
# View rollout history
kubectl rollout history deployment/url-shortener -n url-shortener

# Rollback to previous version
kubectl rollout undo deployment/url-shortener -n url-shortener

# Rollback to a specific revision
kubectl rollout undo deployment/url-shortener -n url-shortener --to-revision=2
```

## 🗑️ Cleanup

### Delete the Deployment

```bash
kubectl delete deployment url-shortener -n url-shortener
```

### Delete the Secret

```bash
kubectl delete secret url-shortener-secret -n url-shortener
```

### Delete the Namespace

```bash
kubectl delete namespace url-shortener
```

## 📊 Resource Considerations

### CPU & Memory Limits

The current limits (200m CPU, 128Mi memory) are conservative. For production, consider:
- **Development**: 100m CPU / 64Mi Memory
- **Staging**: 200m CPU / 128Mi Memory
- **Production**: 500m CPU / 256Mi Memory (adjust based on load testing)

### Autoscaling

To enable horizontal pod autoscaling, add a HorizontalPodAutoscaler:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: url-shortener-hpa
  namespace: url-shortener
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: url-shortener
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## 🔌 Network & Service

To expose the application outside the cluster, create a Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: url-shortener-service
  namespace: url-shortener
spec:
  type: LoadBalancer
  selector:
    api: url-shortener-api
  ports:
  - port: 80
    targetPort: 3333
    protocol: TCP
```

## 🐛 Troubleshooting

### Pods not starting

```bash
kubectl describe pod <pod-name> -n url-shortener
kubectl logs <pod-name> -n url-shortener
```

Common issues:
- Image not found (check image name and registry access)
- Environment variables not set (verify secret.yml)
- Resource limits too low (check node available resources)

### Database connection issues

- Ensure PostgreSQL and Redis services are accessible from the pod
- Update DATABASE_URL and REDIS_URL in secret.yml with correct endpoints
- Test connectivity from a pod: `kubectl exec -it <pod-name> -n url-shortener -- curl <database-host>`

### Image pull errors

```bash
# Check image pull secrets
kubectl get secrets -n url-shortener

# Create secret for private registry if needed
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n url-shortener
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Deployment API](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#deployment-v1-apps)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
