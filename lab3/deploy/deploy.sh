#!/bin/bash
# Deploy a new image version to the target node.
# Called via SSH from the GitHub Actions runner.
# Required env vars: IMAGE_TAG, CR_PAT, GHCR_USER
# TARGET_USER must be in the docker group and have passwordless sudo for systemctl.
set -euo pipefail

REGISTRY="ghcr.io"
REPO="aligheri/deployment-lab1"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE="${REGISTRY}/${REPO}:${IMAGE_TAG}"

echo "Deploying ${FULL_IMAGE}..."

# Authenticate to GitHub Container Registry
echo "${CR_PAT}" | docker login "${REGISTRY}" -u "${GHCR_USER}" --password-stdin

# Pull the new image
docker pull "${FULL_IMAGE}"

# Update image reference for systemd unit
echo "IMAGE=${FULL_IMAGE}" | sudo tee /etc/mywebapp/image.env > /dev/null

# Restart container via systemd
sudo systemctl restart mywebapp

# Wait up to 60 s for the service to become healthy
echo "Waiting for service to start..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:8080/health/alive > /dev/null 2>&1; then
        echo "Service is healthy after $((i * 2)) s"
        exit 0
    fi
    sleep 2
done

echo "ERROR: service did not start within 60 s" >&2
sudo journalctl -u mywebapp --no-pager -n 50 >&2
exit 1
