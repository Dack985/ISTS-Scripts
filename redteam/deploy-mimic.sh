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
IP_LIST=("192.168.0.1" "192.168.0.2" "192.168.0.3")  # Add more IPs as needed

# Define SSH options
SSH_OPTIONS="-o StrictHostKeyChecking=no \
             -o ConnectTimeout=1 \
             -o PreferredAuthentications=password \
             -o PubkeyAuthentication=no \
             -o KexAlgorithms=+diffie-hellman-group14-sha1 \
             -o HostKeyAlgorithms=+ssh-rsa \
             -o PubkeyAcceptedKeyTypes=+ssh-rsa"

# Deployment function (runs in parallel)
deploy_mimic() {
    local address=$1
    echo "Deploying to $address..."

    sshpass -n -p "$PASSWORD" ssh $SSH_OPTIONS -p "$PORT" "$USERNAME@$address" << EOF
        # Install Git if not installed
        if ! command -v git &> /dev/null; then
            echo "$PASSWORD" | sudo -S apt update && echo "$PASSWORD" | sudo -S apt install -y git
        fi

        # Ensure passwordless sudo is set up
        echo "$PASSWORD" | sudo -S bash -c 'echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME'
        echo "$PASSWORD" | sudo -S chmod 0440 /etc/sudoers.d/$USERNAME

        # Clone Mimic repository (if not already cloned)
        if [ ! -d "Mimic" ]; then
            git clone https://github.com/Dack985/Mimic.git
        fi

        # Change directory, set permissions, and execute Mimic
        cd Mimic
        echo "$PASSWORD" | sudo -S chmod +x mimic-v3
        echo "Starting Mimic on $address..."
        echo "$PASSWORD" | sudo -S ./mimic-v3 &
EOF
}

# Run all deployments in parallel
for IP in "${IP_LIST[@]}"; do
    deploy_mimic "$IP" &
done

wait  # Wait for all background jobs to complete
echo "Deployment finished!"
