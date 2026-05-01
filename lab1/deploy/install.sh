#!/bin/bash
set -e

N=5
APP_JAR="mywebapp.jar"
APP_DIR="/opt/mywebapp"
CONFIG_DIR="/etc/mywebapp"
DB_NAME="mywebapp"
DB_USER="mywebapp"
DB_PASS="mywebapp_pass"

apt-get update -y
apt-get install -y openjdk-21-jre-headless nginx postgresql python3 python3-pip python3-yaml
pip3 install psycopg2-binary --break-system-packages

systemctl enable postgresql
systemctl start postgresql

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}'"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER}"

id mywebapp &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin mywebapp

DEFAULT_PASS=$(openssl passwd -6 "12345678")

useradd -m -s /bin/bash student 2>/dev/null || true
usermod -p "${DEFAULT_PASS}" student
usermod -aG sudo student

useradd -m -s /bin/bash teacher 2>/dev/null || true
usermod -p "${DEFAULT_PASS}" teacher
usermod -aG sudo teacher
chage -d 0 teacher

useradd -m -s /bin/bash -N -g operator operator 2>/dev/null || true
usermod -p "${DEFAULT_PASS}" operator
chage -d 0 operator

cat > /etc/sudoers.d/operator << 'EOF'
operator ALL=(ALL) NOPASSWD: /bin/systemctl start mywebapp, \
                              /bin/systemctl stop mywebapp, \
                              /bin/systemctl restart mywebapp, \
                              /bin/systemctl status mywebapp, \
                              /bin/systemctl reload nginx
EOF
chmod 440 /etc/sudoers.d/operator

mkdir -p "${APP_DIR}" "${CONFIG_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "${SCRIPT_DIR}/config/config.yaml" "${CONFIG_DIR}/config.yaml"
sed -i "s/mywebapp_pass/${DB_PASS}/g" "${CONFIG_DIR}/config.yaml"
chown -R mywebapp:mywebapp "${CONFIG_DIR}"
chmod 640 "${CONFIG_DIR}/config.yaml"

cp "${SCRIPT_DIR}/migrate.py" "${APP_DIR}/migrate.py"
chmod +x "${APP_DIR}/migrate.py"

JAR_PATH=$(find "${SCRIPT_DIR}/../build/libs/" -name "*.jar" ! -name "*plain*" | head -1)
if [ -z "${JAR_PATH}" ]; then
    echo "ERROR: JAR not found in build/libs/. Run ./gradlew bootJar first." >&2
    exit 1
fi
cp "${JAR_PATH}" "${APP_DIR}/mywebapp.jar"
chown -R mywebapp:mywebapp "${APP_DIR}"

cp "${SCRIPT_DIR}/systemd/mywebapp.service" /etc/systemd/system/mywebapp.service
cp "${SCRIPT_DIR}/systemd/mywebapp.socket"  /etc/systemd/system/mywebapp.socket

cp "${SCRIPT_DIR}/nginx/mywebapp.conf" /etc/nginx/sites-available/mywebapp
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/mywebapp
nginx -t

systemctl daemon-reload
systemctl enable mywebapp.socket
systemctl start mywebapp.socket
systemctl enable mywebapp
systemctl start mywebapp

systemctl enable nginx
systemctl restart nginx

DEFAULT_USER=$(getent passwd 1000 | cut -d: -f1 || true)
if [ -n "${DEFAULT_USER}" ] && [ "${DEFAULT_USER}" != "student" ]; then
    usermod -L "${DEFAULT_USER}" || true
fi

mkdir -p /home/student
echo "${N}" > /home/student/gradebook
chown student:student /home/student/gradebook

echo "Installation complete"
