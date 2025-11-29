#!/bin/bash
# Deploy script for URL Shortener API

set -e

ENVIRONMENT="${1:-dev}"
K8S_DIR="$(dirname "$0")/../../k8s"

echo "Deploying to $ENVIRONMENT environment"

case "$ENVIRONMENT" in
  dev)
    OVERLAY_PATH="$K8S_DIR/api/overlays/dev"
    ;;
  staging)
    OVERLAY_PATH="$K8S_DIR/api/overlays/staging"
    ;;
  prod)
    OVERLAY_PATH="$K8S_DIR/api/overlays/prod"
    ;;
  *)
    echo "Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 {dev|staging|prod}"
    exit 1
    ;;
esac

echo "Applying Kustomize configuration from: $OVERLAY_PATH"
kubectl apply -k "$OVERLAY_PATH"

echo "Deployment complete!"
echo "To check deployment status, run:"
echo "  kubectl get deployments -n $ENVIRONMENT"
echo "  kubectl get pods -n $ENVIRONMENT"
