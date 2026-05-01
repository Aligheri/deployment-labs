#!/bin/bash
# Self-hosted runner setup for Ubuntu 24.04.
# Installs Docker, Java, and the GitHub Actions runner binary.
# Usage: sudo bash setup-runner.sh
#
# After this script: register the runner MANUALLY (do not add tokens to the repo):
#   cd /opt/actions-runner
#   sudo -u runner ./config.sh \
#     --url https://github.com/Aligheri/deployment-lab1 \
#     --token <TOKEN_FROM_GITHUB_SETTINGS> \
#     --labels deploy \
#     --name deploy-runner \
#     --unattended
#   /opt/actions-runner/svc.sh install runner
#   /opt/actions-runner/svc.sh start
#
# Token location: GitHub repo → Settings → Actions → Runners → New self-hosted runner
#
# IMPORTANT: stop/delete this VM after lab demonstrations are complete.
set -euo pipefail

RUNNER_USER="runner"
RUNNER_DIR="/opt/actions-runner"
RUNNER_VERSION="2.322.0"

apt-get update -y
apt-get install -y curl jq git ca-certificates openjdk-21-jdk-headless openssh-client

# Create runner user
id "${RUNNER_USER}" &>/dev/null || useradd -m -s /bin/bash "${RUNNER_USER}"

# Install Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
systemctl enable --now docker
usermod -aG docker "${RUNNER_USER}"

# Download and install runner
mkdir -p "${RUNNER_DIR}"
curl -sL \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    | tar -xz -C "${RUNNER_DIR}"
chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_DIR}"

# Generate SSH key for connecting to target node
sudo -u "${RUNNER_USER}" ssh-keygen \
    -t ed25519 \
    -f "/home/${RUNNER_USER}/.ssh/target_key" \
    -N "" \
    -C "deploy-runner" 2>/dev/null || true

echo ""
echo "=== Runner installation complete ==="
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Copy runner's public key to target node authorized_keys:"
echo "   cat /home/${RUNNER_USER}/.ssh/target_key.pub"
echo "   (add to ~/.ssh/authorized_keys on the target node)"
echo ""
echo "2. Add GitHub Secrets in the repository settings:"
echo "   TARGET_HOST  — IP or hostname of the target node"
echo "   TARGET_USER  — SSH user on the target node"
echo "   TARGET_SSH_KEY — content of /home/${RUNNER_USER}/.ssh/target_key"
echo "   CR_PAT       — GitHub PAT with read:packages scope"
echo ""
echo "3. Register the runner (TOKEN from GitHub repo → Settings → Actions → Runners):"
echo "   cd ${RUNNER_DIR}"
echo "   sudo -u ${RUNNER_USER} ./config.sh \\"
echo "     --url https://github.com/Aligheri/deployment-lab1 \\"
echo "     --token <TOKEN> \\"
echo "     --labels deploy \\"
echo "     --name deploy-runner \\"
echo "     --unattended"
echo "   ${RUNNER_DIR}/svc.sh install ${RUNNER_USER}"
echo "   ${RUNNER_DIR}/svc.sh start"
