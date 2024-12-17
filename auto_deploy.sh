#!/bin/bash

set -e

# User Configuration
CONTAINER_NAME="obs-vnc-lxc"
TEMPLATE="local:vztmpl/debian-11-standard_11.6-1_amd64.tar.zst"
STORAGE="local-lvm"
MEMORY=1024
CORES=2
SHARED_DIR="/host/shared"
ARCH="amd64"
DNS_SERVER="192.168.100.200"

# Function to check and download LXC template
function check_template() {
    echo "Checking for Debian 11 template..."
    if ! pveam list local | grep -q "debian-11-standard"; then
        echo "Template not found. Downloading the Debian 11 template..."
        pveam update
        if ! pveam download local debian-11-standard_11.6-1_amd64.tar.zst; then
            echo "Error: Failed to download template. Check your network or Proxmox storage."
            exit 1
        fi
    else
        echo "Template already exists."
    fi
}

# Function to check and create the shared directory
function create_shared_dir() {
    if [ ! -d "${SHARED_DIR}" ]; then
        echo "Creating shared directory on the host: ${SHARED_DIR}"
        mkdir -p ${SHARED_DIR}
        chmod 777 ${SHARED_DIR}
    fi
}

# Function to prompt for Container ID
function prompt_container_id() {
    while true; do
        read -p "Enter the Container ID (e.g., 100): " CONTAINER_ID

        # Check if input is a valid number
        if ! [[ "${CONTAINER_ID}" =~ ^[0-9]+$ ]]; then
            echo "Error: Container ID must be a number. Please try again."
            continue
        fi

        # Check if the Container ID is already in use
        if pct list | grep -q "^\\s*${CONTAINER_ID}\\s"; then
            echo "Error: Container ID ${CONTAINER_ID} is already in use. Please choose another ID."
            continue
        fi

        break
    done
}

# Step 1: Prompt for Container ID
prompt_container_id

# Step 2: Check and Download Template
check_template

# Step 3: Create Shared Directory
create_shared_dir

# Step 4: Create the LXC container
echo "Creating LXC container with ID ${CONTAINER_ID}..."
pct create ${CONTAINER_ID} ${TEMPLATE} \
    --arch ${ARCH} \
    --features nesting=1 \
    --hostname ${CONTAINER_NAME} \
    --storage ${STORAGE} \
    --cores ${CORES} \
    --memory ${MEMORY} \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp

# Step 5: Set architecture and DNS server in LXC configuration
echo "Configuring LXC container..."
cat <<EOF > /etc/pve/lxc/${CONTAINER_ID}.conf
# LXC Configuration for Docker, Shared Memory, and DNS
features: nesting=1
arch: ${ARCH}
lxc.cgroup.memory.limit_in_bytes: 256M
mp0: ${SHARED_DIR},mp=/shared
nameserver: ${DNS_SERVER}
EOF

# Step 6: Start the container
echo "Starting the container..."
pct start ${CONTAINER_ID}

# Step 7: Install dependencies and set up OBS VNC inside the container
echo "Installing dependencies and setting up OBS VNC..."
pct exec ${CONTAINER_ID} -- bash -c "
    echo 'nameserver ${DNS_SERVER}' > /etc/resolv.conf
    apt update && apt install -y curl gnupg2 apt-transport-https software-properties-common
    curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
    add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable'
    apt update && apt install -y docker-ce docker-ce-cli containerd.io tigervnc-standalone-server x11-apps
"

# Step 8: Copy files into the container
echo "Copying Docker and systemd files into the container..."
pct push ${CONTAINER_ID} ./Dockerfile /root/Dockerfile
pct push ${CONTAINER_ID} ./docker-compose.yml /root/docker-compose.yml
pct push ${CONTAINER_ID} ./systemd/obs-vnc.service /etc/systemd/system/obs-vnc.service

# Step 9: Run OBS VNC Docker service
echo "Setting up OBS VNC Docker service..."
pct exec ${CONTAINER_ID} -- bash -c "
    cd /root
    docker-compose up -d
    systemctl daemon-reload
    systemctl enable obs-vnc
    systemctl start obs-vnc
"

echo "Deployment complete! OBS VNC is running on port 5901."
