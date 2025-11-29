# Secrets Management Guide

## Overview

Kubernetes Secrets store sensitive configuration and credentials. This guide covers secret management for the URL Shortener API deployment.

## Current Secret Structure

Location: `k8s/api/base/secret.yaml`

### Secret Variables

| Variable | Purpose | Current Value (decoded) |
|----------|---------|------------------------|
| `NODE_ENV` | Application environment | `development` |
| `PORT` | API port | `3333` |
| `CLIENT_URL` | Frontend URL | `http://localhost:3000` |
| `BETTER_AUTH_URL` | Authentication service | `http://localhost:3333` |
| `DATABASE_URL` | PostgreSQL connection | `postgresql://localhost:5432/url_shortener` |
| `DATABASE_USERNAME` | DB user | `postgres` |
| `DATABASE_PASSWORD` | DB password | `postgres` |
| `DATABASE_NAME` | Database name | `url_shortener_pg` |
| `REDIS_URL` | Redis connection | `redis://localhost:6379` |
| `REDIS_PASSWORD` | Redis password | `redis` |

## Decoding Secrets

Kubernetes stores secrets in base64 encoding (not encryption by default).

### View All Secrets
```bash
kubectl get secrets -n dev
```

### View Secret Content
```bash
# Show secret in YAML format
kubectl get secret url-shortener-secret -n dev -o yaml
```

### Decode Individual Values
```bash
# Example: Decode DATABASE_PASSWORD
kubectl get secret url-shortener-secret -n dev -o jsonpath='{.data.DATABASE_PASSWORD}' | base64 -d
```

### Decode All Values (Linux/Mac)
```bash
kubectl get secret url-shortener-secret -n dev -o json | jq '.data | map_values(@base64d)'
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
