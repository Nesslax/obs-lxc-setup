#!/bin/bash

set -e

# User Configuration
CONTAINER_ID=500
CONTAINER_NAME="obs-vnc-lxc"
TEMPLATE="local:vztmpl/debian-11-standard_11.6-1_amd64.tar.zst"
STORAGE="local-lvm"
MEMORY=2048
CORES=2
SHARED_DIR="/host/shared"

echo "Step 1: Updating Proxmox templates..."
pveam update
if ! pveam list local | grep -q "debian-11"; then
    echo "Downloading Debian 11 template..."
    pveam download local debian-11-standard_11.6-1_amd64.tar.zst
fi

echo "Step 2: Creating LXC container..."
pct create ${CONTAINER_ID} ${TEMPLATE} \
    --features nesting=1 \
    --hostname ${CONTAINER_NAME} \
    --storage ${STORAGE} \
    --cores ${CORES} \
    --memory ${MEMORY} \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp

echo "Step 3: Configuring LXC container..."
cat <<EOF > /etc/pve/lxc/${CONTAINER_ID}.conf
# LXC Configuration for Docker and Shared Memory
features: nesting=1
lxc.cgroup.memory.limit_in_bytes: 256M
mp0: ${SHARED_DIR},mp=/shared
EOF

echo "Step 4: Starting the container..."
pct start ${CONTAINER_ID}

echo "Step 5: Installing dependencies and setting up OBS VNC..."
pct exec ${CONTAINER_ID} -- bash -c "apt update && apt install -y curl gnupg2 apt-transport-https software-properties-common"
pct exec ${CONTAINER_ID} -- bash -c "curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -"
pct exec ${CONTAINER_ID} -- bash -c "add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable' && apt update"
pct exec ${CONTAINER_ID} -- bash -c "apt install -y docker-ce docker-ce-cli containerd.io tigervnc-standalone-server x11-apps"

echo "Step 6: Copying configuration and services into the container..."
pct push ${CONTAINER_ID} ./Dockerfile /root/Dockerfile
pct push ${CONTAINER_ID} ./docker-compose.yml /root/docker-compose.yml
pct push ${CONTAINER_ID} ./systemd/obs-vnc.service /etc/systemd/system/obs-vnc.service

echo "Step 7: Setting up and running OBS VNC Docker service..."
pct exec ${CONTAINER_ID} -- bash -c "cd /root && docker-compose up -d"
pct exec ${CONTAINER_ID} -- bash -c "systemctl daemon-reload && systemctl enable obs-vnc && systemctl start obs-vnc"

echo "Deployment complete! OBS VNC is running on port 5901."
