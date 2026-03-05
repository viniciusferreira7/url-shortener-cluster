# Secrets Management Guide

## Overview

Kubernetes Secrets store sensitive configuration and credentials. This guide covers secret management for the URL Shortener API deployment.

## Current Secret Structure

### API — `k8s/api/base/secret.yaml` (name: `url-shortener-secret`)

| Variable | Purpose | Example Value |
|----------|---------|--------------|
| `NODE_ENV` | Application environment | `development` |
| `PORT` | API port | `3333` |
| `CLIENT_URL` | Frontend URL | `http://localhost:3000` |
| `BETTER_AUTH_URL` | Auth service endpoint | `http://localhost:3333` |
| `BETTER_AUTH_SECRET` | Auth service secret | `your-auth-secret` |
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://user:password@postgres-data.dev.svc.cluster.local:5432/url_shortener_pg` |
| `DATABASE_USERNAME` | DB user | `your-db-user` |
| `DATABASE_PASSWORD` | DB password | `your-db-password` |
| `DATABASE_NAME` | Database name | `url_shortener_pg` |
| `REDIS_HOST` | Redis host (in-cluster DNS) | `redis-data.dev.svc.cluster.local` |
| `REDIS_PORT` | Redis port | `6379` |
| `REDIS_DB` | Redis database index | `0` |
| `REDIS_CODE_ID` | Redis code identifier | `your-code-id` |
| `REDIS_PASSWORD` | Redis password | `your-redis-password` |
| `SECRET_HASH_KEY` | Hashing key | `your-hash-key` |
| `GH_TOKEN` | GitHub personal access token | `github_pat_***` |
| `JWT_SECRET` | JWT signing secret | `your-jwt-secret` |

### PostgreSQL — `k8s/database/postgresql/base/secret.yaml` (name: `postgres-secret`)

| Variable | Purpose | Example Value |
|----------|---------|--------------|
| `POSTGRES_USER` | Database user | `your-db-user` |
| `POSTGRES_PASSWORD` | Database password | `your-db-password` |
| `POSTGRES_DB` | Database name | `url_shortener_pg` |

### Redis — `k8s/database/redis/base/secret.yaml` (name: `redis-secret`)

| Variable | Purpose | Example Value |
|----------|---------|--------------|
| `REDIS_HOST` | Redis host | `redis-data.dev.svc.cluster.local` |
| `REDIS_PORT` | Redis port | `6379` |
| `REDIS_DB` | Redis database index | `0` |
| `REDIS_PASSWORD` | Redis password | `your-redis-password` |
| `REDIS_CODE_ID` | Redis code identifier | `your-code-id` |

## Decoding Secrets

Kubernetes stores secrets in base64 encoding (not encryption by default).

### View All Secrets
```bash
kubectl get secrets -n dev
```

### View Secret Content
```bash
kubectl get secret url-shortener-secret -n dev -o yaml
kubectl get secret postgres-secret -n dev -o yaml
kubectl get secret redis-secret -n dev -o yaml
```

### Decode Individual Values
```bash
# API
kubectl get secret url-shortener-secret -n dev -o jsonpath='{.data.DATABASE_PASSWORD}' | base64 -d

# PostgreSQL
kubectl get secret postgres-secret -n dev -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d

# Redis
kubectl get secret redis-secret -n dev -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d
```

### Decode All Values (Linux/Mac)
```bash
kubectl get secret url-shortener-secret -n dev -o json | jq '.data | map_values(@base64d)'
kubectl get secret postgres-secret -n dev -o json | jq '.data | map_values(@base64d)'
kubectl get secret redis-secret -n dev -o json | jq '.data | map_values(@base64d)'
```

## Updating Secrets

### Option 1: Edit YAML and Reapply

1. Update `k8s/api/base/secret.yaml` with new base64-encoded values:

```bash
# Encode a new value
echo -n "new-password" | base64
# Output: bmV3LXBhc3N3b3Jk

# Update the YAML file
vi k8s/api/base/secret.yaml
```

2. Apply the changes:
```bash
kubectl apply -k k8s/api/overlays/dev
```

### Option 2: Create from Literal (Imperative)

```bash
kubectl create secret generic url-shortener-secret \
  --from-literal=NODE_ENV=production \
  --from-literal=PORT=3333 \
  --from-literal=DATABASE_PASSWORD=new-password \
  -n dev \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

### Option 3: Create from File

Create a `.env` file:
```
NODE_ENV=production
PORT=3333
DATABASE_PASSWORD=new-password
```

Then create secret:
```bash
kubectl create secret generic url-shortener-secret \
  --from-env-file=.env \
  -n dev \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

## Security Best Practices

⚠️ **Important**: The current setup is NOT secure for production!

### Current Limitations
- Secrets stored as base64 (encoding, not encryption)
- Secret file committed to version control (if not in .gitignore)
- No encryption at rest
- No audit logging

### Recommended Improvements for Production

1. **Use Sealed Secrets**
   - Encrypt secrets at rest
   - Sign and verify secrets
   ```bash
   # Install sealed-secrets controller
   kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/sealed-secrets-0.18.0.yaml
   ```

2. **Use External Secret Management**
   - HashiCorp Vault
   - AWS Secrets Manager
   - Azure Key Vault
   - Google Secret Manager

3. **External Secrets Operator**
   ```bash
   # Install ESO
   helm repo add external-secrets https://charts.external-secrets.io
   helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
   ```

4. **Encrypt Secrets at Rest**
   ```bash
   # Enable encryption in kind config
   vi infra/kind/config.yaml
   ```

5. **RBAC (Role-Based Access Control)**
   - Restrict who can read secrets
   - Audit secret access

## Encoding/Decoding Reference

### Encode to Base64
```bash
echo -n "my-secret-value" | base64
# Output: bXktc2VjcmV0LXZhbHVl
```

### Decode from Base64
```bash
echo "bXktc2VjcmV0LXZhbHVl" | base64 -d
# Output: my-secret-value
```

## Migration Path

### Step 1: Add to .gitignore
Ensure `secret.yaml` is in `.gitignore` (already configured)

### Step 2: Externalize Secrets
Move secrets to external system (Vault, AWS Secrets Manager, etc.)

### Step 3: Use External Secrets Operator
Reference external secrets in Kustomize patches

### Step 4: Remove from Git History
```bash
git rm --cached k8s/api/base/secret.yaml
```

## Environment-Specific Secrets

### For Staging
Create: `k8s/api/overlays/staging/secret-staging.yaml`

### For Production
Create: `k8s/api/overlays/prod/secret-prod.yaml`

Then reference in overlay `kustomization.yaml`:
```yaml
secretGenerator:
  - name: url-shortener-secret
    envs:
      - secret-prod.env
```

## Monitoring Secret Access

```bash
# View events
kubectl get events -n dev --sort-by='.lastTimestamp'

# Check audit logs (requires audit logging enabled)
kubectl logs -n kube-system -l component=kube-apiserver
```
