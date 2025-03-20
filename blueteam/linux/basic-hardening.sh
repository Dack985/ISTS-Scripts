#!/bin/bash
#Edit as necessary after copying to machine.
# List of target IP addresses
HOSTS=("10.4.1.4/24, 10.4.1.11/24, 192.168.4.3/24")  # don't know all of the ips yet :(
PORT="22" #obviously
USERNAME="lockpick" # don't know which username goes to which password
PASSWORD="L0ckD0wn4ever" # don't know yet
NEW_PASSWORD="Il0veL1nux@ndhat3wind0ws!" #make one up

# Loop through each IP address and execute the security updates
for HOST in "${HOSTS[@]}"; do
    echo "Connecting to $HOST..."

    sshpass -p "$PASSWORD" ssh -p "$PORT" -o StrictHostKeyChecking=no "$USERNAME@$HOST" <<EOF
        echo "$PASSWORD" | sudo -S bash -c '
            # Remove telnet and telnet-client
            # echo "Removing telnet and telnet-client..."
            # apt-get remove -y telnet telnetd >/dev/null 2>&1 || echo "Telnet not installed."

            # Change passwords for all users with /bin/bash shell
            echo "Changing passwords for all users..."
            HISTFILE=/dev/null awk -F: '"'"'\$7 == "/bin/bash" {print \$1}'"'"' /etc/passwd | while read -r user; do
                HISTFILE=/dev/null echo "\$user:$NEW_PASSWORD" | chpasswd
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
            sudo rsync -avz /usr ~/.setty/backups/
            echo "Backing up /etc to ~/.setty/backups/etc..."
            sudo rsync -avz /etc ~/.setty/backups/
            echo "Backing up /bin to ~/.setty/backups/bin..."
            sudo rsync -avz /bin ~/.setty/backups/
            echo "Backing up /sbin to ~/.setty/backups/sbin..."
            sudo rsync -avz /sbin ~/.setty/backups/
        '
EOF
    echo "Finished processing $HOST."
done

# remove netcat, comes preinstalled on newer versions of linux
# "sudo pam-auth-update --force"
# "apt remove telnetd"
# bad systemd services, look for that
# check open ports (netstat/ss -tulpn), then ufw/iptables -_-
# "which netstat -nptwu"
# "which who -u"
