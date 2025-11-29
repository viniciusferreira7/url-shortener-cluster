#!/bin/bash
# Cleanup script for kind cluster

set -e

CLUSTER_NAME="${CLUSTER_NAME:-url-shortener}"

echo "Deleting kind cluster: $CLUSTER_NAME"
kind delete cluster --name "$CLUSTER_NAME"

echo "Cluster cleanup complete!"
