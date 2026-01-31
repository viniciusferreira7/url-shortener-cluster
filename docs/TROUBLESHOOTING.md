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

# Check readiness probes
kubectl get pod POD_NAME -n dev -o yaml | grep -A 5 "readinessProbe"

# Check dependencies (DB, Redis)
# Verify DATABASE_URL and REDIS_URL are correct
kubectl get secret url-shortener-secret -n dev -o yaml
```

### Health Probe Issues

#### Pods stuck in "Not Ready" state or restarting

The deployment uses three types of health probes:
- **startupProbe**: `/api/healthz` - Checks if the application has started (runs first)
- **livenessProbe**: `/api/healthz` - Detects broken application state and restarts container
- **readinessProbe**: `/api/readyz` - Checks if the pod can receive traffic

```bash
# Check pod status and restart count
kubectl get pods -n dev

# View probe configuration
kubectl describe pod POD_NAME -n dev | grep -A 10 "Probes"

# Check for probe-related events
kubectl get events -n dev --sort-by='.lastTimestamp' | grep -i probe

# View container logs
kubectl logs POD_NAME -n dev

# View previous container logs (if restarted)
kubectl logs POD_NAME -n dev --previous
```

#### Startup probe failing

If pods are restarting due to startup probe failures:

```bash
# Check how long the app takes to start
kubectl logs POD_NAME -n dev --previous

# Test the health endpoint manually
kubectl port-forward POD_NAME -n dev 3333:3333
curl http://localhost:3333/api/healthz

# View startup probe configuration
kubectl get deployment url-shortener -n dev -o yaml | grep -A 6 "startupProbe"
```

**Common causes:**
- Application takes longer than 30 seconds to start (3 failures × 10s period)
- Dependencies (database, Redis) are not available
- Health endpoint `/api/healthz` is not implemented or returning errors
- Resource constraints preventing fast startup

**Solutions:**
1. Increase `failureThreshold` or `periodSeconds` in the startup probe
2. Fix dependency availability issues
3. Optimize application startup time
4. Increase resource limits (CPU/memory)

#### Liveness probe failing (container restarts)

If containers are restarting repeatedly due to liveness probe failures:

```bash
# Check restart count
kubectl get pods -n dev
kubectl describe pod POD_NAME -n dev | grep "Restart Count"

# View logs from the previous container instance
kubectl logs POD_NAME -n dev --previous

# Check for liveness probe failures in events
kubectl get events -n dev --sort-by='.lastTimestamp' | grep -i liveness

# Test the liveness endpoint manually
kubectl port-forward POD_NAME -n dev 3333:3333
curl -v http://localhost:3333/api/healthz

# View liveness probe configuration
kubectl get deployment url-shortener -n dev -o yaml | grep -A 8 "livenessProbe"

# Check resource usage (potential cause of hangs)
kubectl top pods -n dev
```

**Common causes:**
- Application deadlocks or infinite loops
- Memory exhaustion (OOMKilled)
- CPU starvation causing slow response times
- Database connection pool exhaustion
- External service timeouts blocking the health check
- Thread pool exhaustion
- `/api/healthz` endpoint returning errors or timing out

**Solutions:**
1. **Review application logs** for errors before restart:
   ```bash
   kubectl logs POD_NAME -n dev --previous | tail -100
   ```

2. **Check for resource constraints**:
   ```bash
   kubectl describe pod POD_NAME -n dev | grep -A 5 "Limits"
   kubectl top pods -n dev
   ```

3. **Increase resource limits** if the application is hitting CPU/memory limits:
   ```yaml
   resources:
     limits:
       cpu: 500m      # Increase from 200m
       memory: 256Mi  # Increase from 192Mi
   ```

4. **Adjust liveness probe timing** if the application legitimately needs more time:
   ```yaml
   livenessProbe:
     periodSeconds: 60        # Increase from 30s
     failureThreshold: 5      # Increase from 3
     initialDelaySeconds: 120 # Increase from 60s
   ```

5. **Fix application issues**:
   - Add proper error handling in the health endpoint
   - Implement connection pool monitoring and recovery
   - Add timeout protection for external service calls
   - Fix memory leaks or deadlock conditions

6. **Monitor for patterns**:
   ```bash
   # Watch for restart patterns
   kubectl get pods -n dev -w

   # Check if restarts correlate with high load
   kubectl top pods -n dev
   ```

#### Readiness probe failing

If pods are not receiving traffic:

```bash
# Check readiness status
kubectl get pods -n dev

# Test the readiness endpoint
kubectl port-forward POD_NAME -n dev 3333:3333
curl http://localhost:3333/api/readyz

# View readiness probe configuration
kubectl get deployment url-shortener -n dev -o yaml | grep -A 6 "readinessProbe"

# Check service endpoints (should only include ready pods)
kubectl get endpoints url-shortener-service -n dev
```

**Common causes:**
- `/api/readyz` endpoint returns non-200 status code
- Application dependencies are unhealthy
- Application is overloaded or responding slowly
- Database or Redis connection issues

**Solutions:**
1. Check application logs for errors
2. Verify database and Redis connectivity
3. Check if resources are sufficient (CPU/memory)
4. Review application logic in the readiness endpoint
5. Temporarily increase `timeoutSeconds` or `periodSeconds` for debugging

#### Load testing and stress testing

Use the stress test script to validate performance under load:

```bash
# Run stress test
bash infra/scripts/test.sh dev

# Monitor during test
kubectl top pods -n dev
kubectl get hpa -n dev -w
kubectl logs -f -n dev -l api=url-shortener-api
```

If the application performs poorly under load:
1. Check HPA configuration and scaling thresholds
2. Review resource limits (CPU/Memory)
3. Monitor for CrashLoopBackOff or OOMKilled events
4. Check application logs for errors
5. Verify external dependencies (database, Redis) are responding

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
