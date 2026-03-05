#!/bin/bash
# Deploy script for URL Shortener API

set -e

ENVIRONMENT="${1:-dev}"
K8S_DIR="$(dirname "$0")/../../k8s"

echo "Deploying to $ENVIRONMENT environment"

case "$ENVIRONMENT" in
  dev|staging|prod)
    API_OVERLAY="$K8S_DIR/api/overlays/$ENVIRONMENT"
    POSTGRES_OVERLAY="$K8S_DIR/database/postgresql/overlays/$ENVIRONMENT"
    REDIS_OVERLAY="$K8S_DIR/database/redis/overlays/$ENVIRONMENT"
    ;;
  *)
    echo "Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 {dev|staging|prod}"
    exit 1
    ;;
esac

echo "Creating namespace if it doesn't exist..."
kubectl create namespace "$ENVIRONMENT" --dry-run=client -o yaml | kubectl apply -f -

echo "Applying PostgreSQL configuration..."
kubectl apply -k "$POSTGRES_OVERLAY"

echo "Applying Redis configuration..."
kubectl apply -k "$REDIS_OVERLAY"

echo "Applying API configuration..."
kubectl apply -k "$API_OVERLAY"

echo "Deployment complete!"
echo "To check deployment status, run:"
echo "  kubectl get deployments,statefulsets -n $ENVIRONMENT"
echo "  kubectl get pods -n $ENVIRONMENT"
