#!/bin/bash

set -e

# User Configuration
CONTAINER_NAME="obs-vnc-lxc"
TEMPLATE="local:vztmpl/debian-11-standard_11.7-1_amd64.tar.zst"
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
        if ! pveam download local debian-11-standard_11.7-1_amd64.tar.zst; then
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

# Function to prompt for root password
function prompt_root_password() {
    while true; do
        read -sp "Enter the root password for the container: " ROOT_PASSWORD
        echo
        read -sp "Confirm the root password: " CONFIRM_PASSWORD
        echo

        if [ "${ROOT_PASSWORD}" != "${CONFIRM_PASSWORD}" ]; then
            echo "Error: Passwords do not match. Please try again."
        else
            echo "Password confirmed."
            break
        fi
    done
}

# Step 1: Prompt for Container ID
prompt_container_id

# Step 2: Prompt for Root Password
prompt_root_password

# Step 3: Check and Download Template
check_template

# Step 4: Create Shared Directory
create_shared_dir

# Step 5: Create the LXC container
echo "Creating LXC container with ID ${CONTAINER_ID}..."
pct create ${CONTAINER_ID} ${TEMPLATE} \
    --ostype debian \
    --arch ${ARCH} \
    --features nesting=1 \
    --hostname ${CONTAINER_NAME} \
    --storage ${STORAGE} \
    --cores ${CORES} \
    --memory ${MEMORY} \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --password "${ROOT_PASSWORD}"

# Step 6: Append configuration to LXC container
echo "Appending LXC configuration..."
cat <<EOF >> /etc/pve/lxc/${CONTAINER_ID}.conf
# Additional LXC Configuration
features: nesting=1
arch: ${ARCH}
mp0: ${SHARED_DIR},mp=/shared
nameserver: ${DNS_SERVER}
EOF

# Step 7: Start the container
echo "Starting the container..."
pct start ${CONTAINER_ID}

# Step 8: Install dependencies and set up OBS VNC inside the container
echo "Installing dependencies and setting up OBS VNC..."
pct exec ${CONTAINER_ID} -- bash -c "
    # Fix DNS resolution
    echo 'nameserver ${DNS_SERVER}' > /etc/resolv.conf
"
pct exec ${CONTAINER_ID} -- bash -c "
    # Update the repository
    echo 'Updating the repository...'
    apt update && apt upgrade -y

    # Install Docker, Docker Compose, and VNC server
    echo 'Installing Docker, Docker Compose, and VNC server...'
    apt install -y docker.io docker-compose tigervnc-standalone-server x11-apps
"

# Step 9: Copy files into the container
echo "Copying Docker and systemd files into the container..."
pct push ${CONTAINER_ID} ./Dockerfile /root/Dockerfile
pct push ${CONTAINER_ID} ./docker-compose.yml /root/docker-compose.yml
pct push ${CONTAINER_ID} ./systemd/obs-vnc.service /etc/systemd/system/obs-vnc.service

# Step 10: Run OBS VNC Docker service
echo "Setting up OBS VNC Docker service..."
pct exec ${CONTAINER_ID} -- bash -c "
    cd /root
    docker-compose up -d
    systemctl daemon-reload
    systemctl enable obs-vnc
    systemctl start obs-vnc
"

echo "Deployment complete! OBS VNC is running on port 5901."
