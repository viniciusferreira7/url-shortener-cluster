#!/bin/bash
# Setup script for kind cluster and URL Shortener deployment

set -e

CLUSTER_NAME="${CLUSTER_NAME:-url-shortener}"
CONFIG_FILE="$(dirname "$0")/../kind/config.yaml"
METRICS_SERVER_FILE="$(dirname "$0")/../kind/metrics-server.yaml"

echo "Applying metrics server"
kubectl apply -f "$METRICS_SERVER_FILE" 

echo "Creating kind cluster: $CLUSTER_NAME"
kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG_FILE"

echo "Setting kubeconfig context"
kubectl cluster-info --context "kind-$CLUSTER_NAME"

echo "Cluster setup complete!"
echo "To use the cluster, run:"
echo "  kubectl config use-context kind-$CLUSTER_NAME"
