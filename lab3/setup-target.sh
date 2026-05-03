#!/bin/bash
# Setup script for the target node (Ubuntu 24.04).
# Installs Docker, PostgreSQL, nginx and configures the environment.
# Based on Lab 1 install.sh.
# Usage: sudo bash setup-target.sh
# DB password is read from DB_PASS env var (default: mywebapp_pass).
set -euo pipefail

DB_NAME="mywebapp"
DB_USER="mywebapp"
DB_PASS="${DB_PASS:-mywebapp_pass}"
APP_USER="mywebapp"
CONFIG_DIR="/etc/mywebapp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

apt-get update -y
apt-get install -y nginx postgresql curl ca-certificates python3 python3-pip

pip3 install --quiet psycopg2-binary --break-system-packages

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

systemctl enable --now docker postgresql

# PostgreSQL setup
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" \
    | grep -q 1 || sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}'"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" \
    | grep -q 1 || sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER}"

# Schema migration
sudo -u postgres psql "${DB_NAME}" << SQL
CREATE TABLE IF NOT EXISTS items (
    id        BIGSERIAL    PRIMARY KEY,
    name      VARCHAR(255) NOT NULL,
    quantity  INTEGER      NOT NULL,
    created_at TIMESTAMP   NOT NULL DEFAULT NOW()
);
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
SQL

# System user to run the container
id "${APP_USER}" &>/dev/null || \
    useradd --system --no-create-home --shell /usr/sbin/nologin "${APP_USER}"
usermod -aG docker "${APP_USER}"

# App config
mkdir -p "${CONFIG_DIR}"
cat > "${CONFIG_DIR}/config.yaml" << EOF
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/${DB_NAME}
    username: ${DB_USER}
    password: ${DB_PASS}
  jpa:
    hibernate:
      ddl-auto: none
    open-in-view: false
server:
  port: 8080
  address: 0.0.0.0
EOF
chown "${APP_USER}:${APP_USER}" "${CONFIG_DIR}/config.yaml"
chmod 640 "${CONFIG_DIR}/config.yaml"

# Placeholder image env file (updated by deploy.sh on each deployment)
echo "IMAGE=ghcr.io/aligheri/deployment-labs:latest" > "${CONFIG_DIR}/image.env"
chown "${APP_USER}:${APP_USER}" "${CONFIG_DIR}/image.env"
chmod 640 "${CONFIG_DIR}/image.env"

# nginx
cp "${SCRIPT_DIR}/deploy/nginx/mywebapp.conf" /etc/nginx/sites-available/mywebapp
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/mywebapp
nginx -t

# systemd unit
cp "${SCRIPT_DIR}/deploy/mywebapp.service" /etc/systemd/system/mywebapp.service
systemctl daemon-reload
systemctl enable mywebapp nginx
systemctl restart nginx

echo "Target node setup complete."
echo "Run 'systemctl start mywebapp' after the first deployment."
