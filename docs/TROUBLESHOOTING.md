# Troubleshooting Guide

## Common Issues and Solutions

### Cluster Issues

#### Cluster not starting
```bash
# Check if Docker is running
docker ps

# Check kind cluster status
kind get clusters
kind get nodes --name url-shortener

# Delete and recreate
bash infra/scripts/cleanup.sh
bash infra/scripts/setup.sh
```

#### Cannot connect to cluster
```bash
# Verify kubectl context
kubectl config current-context

# List available contexts
kubectl config get-contexts

# Switch to correct context
kubectl config use-context kind-url-shortener
```

### Deployment Issues

#### Pods not starting

```bash
# Check pod status
kubectl get pods -n dev

# Describe the pod for events
kubectl describe pod POD_NAME -n dev

# Check pod logs
kubectl logs POD_NAME -n dev

# Common status codes:
# - Pending: Waiting for resources or image pull
# - CrashLoopBackOff: Container keeps crashing
# - ImagePullBackOff: Cannot pull container image
```

#### CrashLoopBackOff

Usually indicates the container is exiting immediately:

```bash
# Check logs
kubectl logs POD_NAME -n dev --previous

# Check resource constraints
kubectl describe pod POD_NAME -n dev | grep -A 5 "Requests"

# Verify environment variables
kubectl exec POD_NAME -n dev -- env
```

#### ImagePullBackOff

```bash
# Verify image exists and is accessible
docker pull vinciusaf/url-shortener-api:4dacc42

# Check image in pod spec
kubectl get deployment url-shortener -n dev -o yaml | grep image

# For private registries, create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=docker.io \
  --docker-username=USERNAME \
  --docker-password=PASSWORD \
  -n dev
```

### Service Issues

#### Service not accessible

```bash
# Verify service exists
kubectl get service url-shortener-service -n dev

# Test internal connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n dev -- sh

# Inside the pod:
curl http://url-shortener-service/health
```

#### Service endpoints not ready

```bash
# Check endpoints
kubectl get endpoints -n dev

# Verify selectors match pod labels
kubectl get pods -n dev --show-labels
kubectl get service url-shortener-service -n dev -o yaml | grep selector -A 3
```

### Resource Issues

#### Insufficient resources

```bash
# Check node capacity
kubectl describe nodes

# Check resource usage
kubectl top nodes
kubectl top pods -n dev

# Check pod resource requests
kubectl get deployment url-shortener -n dev -o yaml | grep -A 10 "resources:"

# Solutions:
# 1. Reduce replica count
# 2. Reduce resource limits
# 3. Add more nodes to cluster
```

#### Quota exceeded

```bash
# Check resource quotas
kubectl get resourcequota -n dev

# Check quota status
kubectl describe resourcequota -n dev
```

### Configuration Issues

#### Kustomize errors

```bash
# Validate kustomization
kubectl kustomize k8s/api/overlays/dev

# Check for YAML syntax errors
kustomize build k8s/api/overlays/dev

# Dry run
kubectl apply -k k8s/api/overlays/dev --dry-run=client
```

#### Secret not found

```bash
# Verify secret exists
kubectl get secret url-shortener-secret -n dev

# Check secret name in deployment
kubectl get deployment url-shortener -n dev -o yaml | grep secretRef -A 2

# Create missing secret
kubectl create secret generic url-shortener-secret \
  --from-literal=NODE_ENV=development \
  --from-literal=PORT=3333 \
  -n dev
```

### Network Issues

#### DNS not working in pod

```bash
# Test DNS
kubectl exec POD_NAME -n dev -- nslookup kubernetes.default

# Check coredns
kubectl get pods -n kube-system | grep coredns

# Verify service DNS name
kubectl exec POD_NAME -n dev -- getent hosts url-shortener-service.dev.svc.cluster.local
```

#### Cannot reach external services

```bash
# Check network policies
kubectl get networkpolicy -n dev

# Test connectivity
kubectl exec POD_NAME -n dev -- curl http://external-service.com

# Check pod DNS
kubectl exec POD_NAME -n dev -- cat /etc/resolv.conf
```

### Persistence Issues

#### ConfigMaps/Secrets not updating

```bash
# Restart pods to pick up changes
kubectl rollout restart deployment/url-shortener -n dev

# Verify changes
kubectl get configmap -n dev -o yaml
kubectl get secret -n dev -o yaml
```

### Logging and Debugging

#### Enable debug logging

```bash
# Kubectl verbose output
kubectl apply -k k8s/api/overlays/dev -v=6

# Pod exec for debugging
kubectl exec -it POD_NAME -n dev -- /bin/bash

# Stream logs
kubectl logs -f -n dev -l api=url-shortener-api

# Logs from previous container
kubectl logs POD_NAME -n dev --previous
```

#### Collecting diagnostic information

```bash
# Cluster info
kubectl cluster-info dump --output-directory=./cluster-dump

# All resources in namespace
kubectl get all -n dev

# Events
kubectl get events -n dev --sort-by='.lastTimestamp'

# Describe all pods
kubectl describe pods -n dev
```

### Performance Issues

#### Slow API responses

```bash
# Check pod resource usage
kubectl top pods -n dev

# Check logs for errors
kubectl logs POD_NAME -n dev

# Check readiness probes (if any)
kubectl get pod POD_NAME -n dev -o yaml | grep -A 5 "readinessProbe"

# Check dependencies (DB, Redis)
# Verify DATABASE_URL and REDIS_URL are correct
kubectl get secret url-shortener-secret -n dev -o yaml
```

### Recovery Procedures

#### Restart deployment

```bash
kubectl rollout restart deployment/url-shortener -n dev

# Monitor rollout
kubectl rollout status deployment/url-shortener -n dev -w
```

#### Rollback deployment

```bash
# View rollout history
kubectl rollout history deployment/url-shortener -n dev

# Rollback to previous revision
kubectl rollout undo deployment/url-shortener -n dev

# Rollback to specific revision
kubectl rollout undo deployment/url-shortener -n dev --to-revision=2
```

#### Clean up resources

```bash
# Delete stuck pods
kubectl delete pod POD_NAME -n dev --grace-period=0 --force

# Clean namespace
kubectl delete all --all -n dev

# Full cleanup
bash infra/scripts/cleanup.sh
```

## Getting Help

### Useful Commands

```bash
# Get detailed help on a resource
kubectl explain deployment

# Check API documentation
kubectl api-resources

# View current configuration
kubectl config view

# Check cluster info
kubectl cluster-info
```

### Documentation Resources

- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
