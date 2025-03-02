#!/bin/bash

# Prompt the user for the file they want to add to .bashrc
read -p "Enter the full path of the script you want to add: " FILE_TO_ADD

# Ensure the file exists
if [[ ! -f "$FILE_TO_ADD" ]]; then
    echo "Error: File does not exist!"
    exit 1
fi

# List of usernames to exclude
EXCLUDED_USERS=("whiteteam" "blackteam" "Whiteteam" "Blackteam" "WhiteTeam" "BlackTeam")

# Loop through all users in /home and also root
for user_dir in /home/* /root; do
    if [[ -d "$user_dir" ]]; then
        # Extract the username
        USERNAME=$(basename "$user_dir")

        # Skip if the username is in the exclusion list
        if [[ " ${EXCLUDED_USERS[@]} " =~ " $USERNAME " ]]; then
            echo "Skipping $USERNAME..."
            continue
        fi

        USER_BASHRC="$user_dir/.bashrc"

        # Check if .bashrc exists, otherwise create it
        if [[ ! -f "$USER_BASHRC" ]]; then
            touch "$USER_BASHRC"
        fi

        # Check if the line is already present
        if ! grep -q "source $FILE_TO_ADD" "$USER_BASHRC"; then
            echo "Adding source line to $USER_BASHRC"
            echo "source $FILE_TO_ADD" >> "$USER_BASHRC"
        else
            echo "Already added in $USER_BASHRC, skipping..."
        fi
    fi
done

echo "Done!"
