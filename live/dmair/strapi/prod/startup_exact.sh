#!/bin/bash
set -euo pipefail

# ----------------------------------------------------
# Add SSH keys for ubuntu user (Jenkins + GitHub Actions)
# ----------------------------------------------------
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh

# Create authorized_keys file
touch /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys

# Add Jenkins SSH key if provided
%{ if JENKINS_SSH_PUBLIC_KEY != "" }
echo "Adding Jenkins SSH public key..."
echo "${JENKINS_SSH_PUBLIC_KEY}" >> /home/ubuntu/.ssh/authorized_keys
%{ endif }

# Add GitHub Actions SSH key if provided
%{ if GITHUB_ACTIONS_SSH_PUBLIC_KEY != "" }
echo "Adding GitHub Actions SSH public key..."
echo "${GITHUB_ACTIONS_SSH_PUBLIC_KEY}" >> /home/ubuntu/.ssh/authorized_keys
%{ endif }

chown -R ubuntu:ubuntu /home/ubuntu/.ssh

echo "-----------------------------------------------"
echo "Installing Docker and Docker Compose"
echo "-----------------------------------------------"

sudo apt -y update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common unzip

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt -y update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker
sudo groupadd docker || true
sudo usermod -aG docker ubuntu


echo "-----------------------------------------------"
echo "Installing AWS CLI v2"
echo "-----------------------------------------------"

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

echo "AWS CLI version:"
aws --version

echo "Setup completed successfully."