# List of target IP addresses
HOSTS=("192.168.56.101" "192.168.56.102" "192.168.56.103")  # Add more IPs as needed
PORT="717"
USERNAME="booth"
PASSWORD="password"
NEW_PASSWORD="iamagigachad"

# Loop through each IP address and execute the security updates
for HOST in "${HOSTS[@]}"; do
    echo "Connecting to $HOST..."

    sshpass -p "$PASSWORD" ssh -p "$PORT" -o StrictHostKeyChecking=no "$USERNAME@$HOST" <<EOF
        echo "$PASSWORD" | sudo -S bash -c '
            # Force update PAM authentication configuration
            #echo "Forcing PAM update..."
            #sudo pam-auth-update --force

            # Remove telnet and telnet-client
            echo "Removing telnet and telnet-client..."
            apt-get remove -y telnet telnet-client >/dev/null 2>&1 || echo "Telnet not installed."

            # Change passwords for all users with /bin/bash shell
            echo "Changing passwords for all users..."
            awk -F: '"'"'\$7 == "/bin/bash" {print \$1}'"'"' /etc/passwd | while read -r user; do
                echo "\$user:$NEW_PASSWORD" | chpasswd
                echo "Password changed for user: \$user"
            done

            # Secure SSH configuration
            echo "Updating SSH settings..."
            sed -i "s/^PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config
            sed -i "s/^PubkeyAuthentication.*/PubkeyAuthentication no/" /etc/ssh/sshd_config
            sed -i "s/^UsePAM.*/UsePAM no/" /etc/ssh/sshd_config
            echo "SSH settings updated."

            # Restart SSH service to apply changes
            echo "Restarting SSH service..."
            systemctl restart ssh
            echo "SSH service restarted."

            # Clear all user crontab contents without deleting the crontab itself
            echo "Clearing all user crontabs..."
            awk -F: '"'"'\$7 == "/bin/bash" {print \$1}'"'"' /etc/passwd | while read -r user; do
                echo "" | crontab -u "\$user" -
                echo "Cleared crontab content for user: \$user"
            done
            echo "All crontab contents cleared."

            # Create a backup directory
            mkdir -p ~/.setty/backups

            # Backup the /usr, /etc, /bin, and /sbin directories
            echo "Backing up /usr to ~/.setty/backups/usr..."
            sudo rsync -avz /usr ~/.setty/backups/usr
            echo "Backing up /etc to ~/.setty/backups/etc..."
            sudo rsync -avz /etc ~/.setty/backups/etc
            echo "Backing up /bin to ~/.setty/backups/bin..."
            sudo rsync -avz /bin ~/.setty/backups/bin
            echo "Backing up /sbin to ~/.setty/backups/sbin..."
            sudo rsync -avz /sbin ~/.setty/backups/sbin
        '
EOF
    echo "Finished processing $HOST."
done
