OBS VNC LXC Deployment

This repository automates the deployment of an OBS VNC Server inside a Proxmox LXC container. The deployment includes Docker, shared memory configuration, a shared directory between the host and container, and an accessible VNC server.

Features

✅ Automatic creation of a Proxmox LXC container

✅ Dockerized OBS VNC server running on port 5901

✅ Persistent shared directory between host and container

✅ Health checks and automatic restarts for reliability

✅ Fully automated with a single script


Requirements
	•	Proxmox VE 6+ (tested on Proxmox VE 7)
	•	SSH access to the Proxmox host
	•	Basic understanding of Proxmox CLI


Installation and Usage

Follow these steps to deploy everything automatically.

1. Clone the Repository

SSH into your Proxmox host and clone this repository:


git clone https://github.com/Nesslax/obs-lxc-setup
cd obs-lxc-setup

2. Make the Script Executable

Ensure the script has execution permissions:

chmod +x auto_deploy.s

3. Run the Deployment Script

Execute the script to deploy everything:

./auto_deploy.sh



What Happens During Deployment?
	1.	Creates a Proxmox LXC container with the following settings:
	•	Debian 11 template
	•	Shared memory limit: 256M
	•	Shared directory between host and container
	2.	Installs Docker and TigerVNC inside the LXC container.
	3.	Builds and runs the OBS VNC Docker container.
	4.	Configures systemd to ensure OBS VNC stays up.




Shared Directory

You can easily transfer files between the Proxmox host and the container:
	•	Host Path: /host/shared
	•	Container Path: /shared

Simply place files into /host/shared on the Proxmox host, and they will appear inside /shared in the container.




Customization

You can customize deployment settings by editing the following files:
	1.	VNC Password (default: 123456):
Modify the docker-compose.yml file:
