#!/bin/bash

set -e

sudo apt update -y

sudo apt install unzip wget curl -y

sudo apt install openjdk-17-jdk -y

sudo sysctl -w vm.max_map_count=524288
sudo sysctl -w fs.file-max=131072

echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=131072" | sudo tee -a /etc/sysctl.conf

wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.6.0.109173.zip

sudo apt install zip -y

sudo unzip sonarqube-25.6.0.109173.zip -d /opt

sudo mv /opt/sonarqube-* /opt/sonarqube

sudo groupadd sonar

sudo useradd -d /opt/sonarqube -g sonar sonar

sudo chown -R sonar:sonar /opt/sonarqube

sudo bash -c 'cat >> /opt/sonarqube/conf/sonar.properties <<EOF
sonar.jdbc.username=${db_user}
sonar.jdbc.password=${db_password}
sonar.jdbc.url=jdbc:postgresql://${db_host}:5432/${db_name}
EOF'

sudo tee /etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube
After=network.target

[Service]
Type=forking
User=sonar
Group=sonar
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube