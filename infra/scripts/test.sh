#!/bin/bash
# Cluster stress test

set -e
ENVIRONMENT="${1:-dev}"

echo "Creating and generating stress test using Fortio"

case "$ENVIRONMENT" in
  dev)
    kubectl run fortio \
      -n dev \
      --rm -it \
      --image=fortio/fortio:1.73.1 \
      -- \
      load -loglevel debug -qps 6000 -t 120s -c 100 \
      http://url-shortener-service/
    ;;
  staging)
    kubectl run fortio \
      -n staging \
      --rm -it \
      --image=fortio/fortio:1.73.1 \
      -- \
      load -loglevel debug -qps 10000 -t 240s -c 150 \
      http://url-shortener-service/
    ;;
  prod)
    kubectl run fortio \
      -n prod \
      --rm -it \
      --image=fortio/fortio:1.73.1 \
      -- \
      load -loglevel debug -qps 1500 -t 360s -c 200 \
      http://url-shortener-service/
    ;;
  *)
    echo "Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 {dev|staging|prod}"
    exit 1
    ;;
esac

echo "Stress test finished"
