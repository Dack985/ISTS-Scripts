#!/bin/bash

# Install sshpass if not installed
if ! command -v sshpass &> /dev/null; then
    echo "Installing sshpass..."
    sudo apt update && sudo apt install -y sshpass
fi

# Define credentials
USERNAME="admin"
PASSWORD="password"
PORT="22"

# List of target IPs
IP_LIST=("192.168.0.1" "192.168.0.2" "192.168.0.3")  # Add your IPs here

# Define SSH options
SSH_OPTIONS="-o StrictHostKeyChecking=no \
             -o ConnectTimeout=1 \
             -o PreferredAuthentications=password \
             -o PubkeyAuthentication=no \
             -o KexAlgorithms=+diffie-hellman-group14-sha1 \
             -o HostKeyAlgorithms=+ssh-rsa \
             -o PubkeyAcceptedKeyTypes=+ssh-rsa"

# Deployment function
deploy_mimic() {
    local address=$1
    echo "Deploying to $address..."

    sshpass -n -p "$PASSWORD" ssh $SSH_OPTIONS -p "$PORT" "$USERNAME@$address" << EOF
        # Install Git if not installed
        if ! command -v git &> /dev/null; then
            sudo apt update && sudo apt install -y git
        fi

        # Clone Mimic repository (if not already cloned)
        if [ ! -d "Mimic" ]; then
            git clone https://github.com/Dack985/Mimic.git
        fi

        # Change directory and setup execution
        cd Mimic
        sudo chmod +x mimic-v3
        echo "Starting Mimic on $address..."
        sudo ./mimic-v3 &
EOF
}

# Run deployment in parallel for each IP
for IP in "${IP_LIST[@]}"; do
    deploy_mimic "$IP" &
done

wait  # Wait for all background jobs to complete
echo "Deployment finished!"

