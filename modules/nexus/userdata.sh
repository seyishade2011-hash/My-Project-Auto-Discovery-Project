#!/bin/bash
set -e

echo "Updating system..."
dnf update -y

echo "Installing dependencies..."
dnf install -y java-17-openjdk wget tar curl

# Variables
NEXUS_USER="nexus"
NEXUS_VERSION="3.80.0-06"
NEXUS_URL="https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-linux-x86_64.tar.gz"

echo "Creating nexus user..."
useradd -m -d /opt/nexus -s /bin/bash $NEXUS_USER || true

echo "Downloading Nexus..."
cd /tmp
wget -O nexus.tar.gz $NEXUS_URL

echo "Extracting Nexus..."
tar -xzf nexus.tar.gz

mv nexus-${NEXUS_VERSION} /opt/nexus
mv sonatype-work /opt/sonatype-work || true

echo "Setting permissions..."
chown -R $NEXUS_USER:$NEXUS_USER /opt/nexus
chown -R $NEXUS_USER:$NEXUS_USER /opt/sonatype-work

chmod +x /opt/nexus/bin/nexus

echo "Configuring Nexus user..."
echo "run_as_user=$NEXUS_USER" > /opt/nexus/bin/nexus.rc

echo "Creating systemd service..."
cat <<EOF > /etc/systemd/system/nexus.service
[Unit]
Description=Nexus Repository Manager
After=network.target

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
systemctl enable nexus
systemctl start nexus

echo "Nexus installation completed!"