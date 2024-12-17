#!/bin/bash

set -e

echo "Updating and installing dependencies..."
apt update && apt install -y curl gnupg2 apt-transport-https lsb-release software-properties-common systemd

echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
apt update && apt install -y docker-ce docker-ce-cli containerd.io

echo "Installing VNC Server..."
apt install -y tigervnc-standalone-server x11-apps

echo "Copying systemd service..."
cp /root/obs-lxc-setup/systemd/obs-vnc.service /etc/systemd/system/obs-vnc.service

echo "Setting up shared directory..."
mkdir -p /host/shared
chmod -R 777 /host/shared

echo "Reloading systemd and starting OBS service..."
systemctl daemon-reload
systemctl enable obs-vnc
systemctl start obs-vnc

echo "Setup complete. OBS with VNC is running."
