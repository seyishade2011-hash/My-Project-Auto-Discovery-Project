#!/bin/bash
set -e

exec > >(tee /var/log/jenkins-userdata.log)
exec 2>&1

#############################################
# Update System
#############################################

yum update -y

#############################################
# Install Required Packages
#############################################

yum install -y \
  git \
  wget \
  curl \
  unzip \
  zip \
  tar \
  jq \
  yum-utils \
  fontconfig \
  dejavu-sans-fonts \
  maven

#############################################
# Install Java 21 - Amazon Corretto
#############################################

rpm --import https://yum.corretto.aws/corretto.key

curl -L -o /etc/yum.repos.d/corretto.repo \
  https://yum.corretto.aws/corretto.repo

yum install -y java-21-amazon-corretto-devel

# Make Java 21 the system default
alternatives --install /usr/bin/java java /usr/lib/jvm/java-21-amazon-corretto/bin/java 21000000
alternatives --set java /usr/lib/jvm/java-21-amazon-corretto/bin/java

java -version

#############################################
# Install Jenkins
#############################################

wget -O /etc/yum.repos.d/jenkins.repo \
  https://pkg.jenkins.io/rpm-stable/jenkins.repo

rpm --import https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key

yum upgrade -y

yum install -y jenkins

#############################################
# Jenkins systemd compatibility
#############################################

mkdir -p /etc/systemd/system/jenkins.service.d

cat > /etc/systemd/system/jenkins.service.d/override.conf <<'EOF'
[Unit]
StartLimitBurst=
StartLimitIntervalSec=
EOF

systemctl daemon-reload

#############################################
# Install Docker
#############################################

amazon-linux-extras install docker -y

systemctl enable docker
systemctl start docker

usermod -aG docker ec2-user
usermod -aG docker jenkins

#############################################
# Install AWS CLI v2
#############################################

cd /tmp

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o awscliv2.zip

unzip -o awscliv2.zip

./aws/install

#############################################
# Install Terraform 1.14.8
#############################################

cd /tmp

wget https://releases.hashicorp.com/terraform/1.14.8/terraform_1.14.8_linux_amd64.zip

unzip -o terraform_1.14.8_linux_amd64.zip

mv terraform /usr/local/bin/terraform

ln -sf /usr/local/bin/terraform /usr/bin/terraform

terraform version

#############################################
# Start Jenkins
#############################################

systemctl daemon-reload

systemctl enable jenkins
systemctl start jenkins

#############################################
# Restart Docker
#############################################

systemctl restart docker

#############################################
# Restart Jenkins
#############################################

systemctl restart jenkins

#############################################
# Save Initial Jenkins Password
#############################################

if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    cp /var/lib/jenkins/secrets/initialAdminPassword \
       /home/ec2-user/jenkins-password.txt

    chown ec2-user:ec2-user \
      /home/ec2-user/jenkins-password.txt
fi

#############################################
# Completion
#############################################

echo "====================================="
echo " Jenkins Installation Complete "
echo "====================================="