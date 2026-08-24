#!/bin/bash
set -e

echo "Updating system..."
dnf update -y

echo "Installing dependencies..."
dnf install -y java-17-openjdk wget tar curl jq

echo "Installing and starting SSM Agent..."
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Variables
NEXUS_USER="nexus"
NEXUS_VERSION="3.80.0-06"
NEXUS_URL="https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-linux-x86_64.tar.gz"

echo "Creating nexus user..."
useradd -m -d /opt/nexus -s /bin/bash "$NEXUS_USER" || true

echo "Downloading Nexus..."
cd /tmp
wget -O nexus.tar.gz "$NEXUS_URL"

echo "Extracting Nexus..."
tar -xzf nexus.tar.gz

rm -rf /opt/nexus
mv "nexus-${NEXUS_VERSION}" /opt/nexus

mkdir -p /opt/sonatype-work

echo "Setting permissions..."
chown -R "$NEXUS_USER:$NEXUS_USER" /opt/nexus
chown -R "$NEXUS_USER:$NEXUS_USER" /opt/sonatype-work

chmod +x /opt/nexus/bin/nexus

echo "Configuring Nexus user..."
echo "run_as_user=$NEXUS_USER" > /opt/nexus/bin/nexus.rc

echo "Creating systemd service..."

cat <<EOF > /etc/systemd/system/nexus.service
[Unit]
Description=Nexus Repository Manager
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
LimitNOFILE=65536
User=$NEXUS_USER
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd..."
systemctl daemon-reload

echo "Starting Nexus manually..."
systemctl start nexus

sleep 10

if systemctl is-active --quiet nexus; then
    echo "Nexus service started successfully."
    systemctl enable nexus
else
    echo "ERROR: Nexus failed to start."
    systemctl status nexus --no-pager || true
    journalctl -u nexus --no-pager -n 100 || true
    exit 1
fi

echo "Waiting for Nexus to become available..."

for i in {1..60}; do
    if curl -fsS http://127.0.0.1:8081/service/rest/v1/status >/dev/null 2>&1; then
        echo "Nexus is ready."
        break
    fi

    echo "Waiting for Nexus... attempt $i/60"
    sleep 10
done

if ! curl -fsS http://127.0.0.1:8081/service/rest/v1/status >/dev/null 2>&1; then
    echo "ERROR: Nexus did not become ready."
    exit 1
fi

echo "Reading initial Nexus admin password..."

ADMIN_PASSWORD_FILE="/opt/sonatype-work/nexus3/admin.password"

if [ ! -f "$ADMIN_PASSWORD_FILE" ]; then
    echo "ERROR: Nexus admin.password file not found."
    exit 1
fi

INITIAL_ADMIN_PASSWORD=$(cat "$ADMIN_PASSWORD_FILE")

echo "Initial admin password found."

# Change the admin password to a known value.
# IMPORTANT: change this value before production use.
NEXUS_ADMIN_PASSWORD="admin123"

echo "Changing Nexus admin password..."

curl -fsS \
    -u "admin:${INITIAL_ADMIN_PASSWORD}" \
    -X PUT \
    -H "Content-Type: text/plain" \
    --data "${NEXUS_ADMIN_PASSWORD}" \
    http://127.0.0.1:8081/service/rest/v1/security/users/admin/change-password

echo "Admin password changed."

echo "Enabling Docker Bearer Token Realm..."

curl -fsS \
    -u "admin:${NEXUS_ADMIN_PASSWORD}" \
    -X PUT \
    -H "Content-Type: application/json" \
    -d '{
      "active": [
        "NexusAuthenticatingRealm",
        "NexusAuthorizingRealm",
        "DockerToken"
      ]
    }' \
    http://127.0.0.1:8081/service/rest/v1/security/realms/active

echo "Docker Bearer Token Realm enabled."

echo "Checking whether Docker repository already exists..."

if curl -fsS \
    -u "admin:${NEXUS_ADMIN_PASSWORD}" \
    http://127.0.0.1:8081/service/rest/v1/repositories/docker/hosted/docker-hosted \
    >/dev/null 2>&1; then

    echo "Docker hosted repository already exists."

else

    echo "Creating Docker hosted repository on port 8085..."

    curl -fsS \
        -u "admin:${NEXUS_ADMIN_PASSWORD}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
          "name": "docker-hosted",
          "online": true,
          "storage": {
            "blobStoreName": "default",
            "strictContentTypeValidation": true,
            "writePolicy": "ALLOW"
          },
          "docker": {
            "v1Enabled": false,
            "forceBasicAuth": true,
            "httpPort": 8085
          }
        }' \
        http://127.0.0.1:8081/service/rest/v1/repositories/docker/hosted

    echo "Docker hosted repository created."
fi

echo "Saving Nexus credentials..."

cat > /home/ec2-user/nexus-credentials.txt <<EOF
NEXUS_USERNAME=admin
NEXUS_PASSWORD=${NEXUS_ADMIN_PASSWORD}
NEXUS_DOCKER_PORT=8085
EOF

chmod 600 /home/ec2-user/nexus-credentials.txt
chown ec2-user:ec2-user /home/ec2-user/nexus-credentials.txt

echo "Nexus installation completed!"