#!/bin/bash

mkdir "$HOME/bak"

git_install () {
    if ! command -v git &> /dev/null; then
        echo "Git is not installed. Installing now..."
        sudo apt install git -y
    else
        echo "Git is already installed good stuff man :)"
    fi
}

git config --global user.name "Local User"
git config --global user.email "local@example.com"

#function to backup to a local git repo
backup_files () {
echo "Do you want to back up a file/folder? (type 1 or 2)"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            while true; do
                read -p "Enter the file/folder path: " file_path

                if [[ -z "$file_path" ]]; then
                    echo "File path cannot be empty. Please try again."
                elif [[ ! -e "$file_path" ]]; then
                    echo "File or directory was not found, point the backup to an existing location"
                else
                    break
                fi
            done
            sudo cp -r "$file_path" "$HOME/bak"
            file_basename=$(basename "$file_path")
            NewPath="$HOME/bak/$file_basename"
            git add "$NewPath"
            git commit -m "user selected file $(date '+%Y-%m-%d %H:%M:%S')"
            echo "backup complete for $NewPath"
            run_it_back
            break
            ;;
        No ) exit ;;
    esac
done
}


run_it_back() {
    echo "Would you like to backup another file"
        select yn in "Yes" "No"; do
        case $yn in
        Yes ) backup_files; break;;
        No ) exit;;
    esac
done
}

#run it baby

git_install



echo "--------------------------------------------------------------------------------"
echo "moving you to the correct location /home and creating a git repo locally for you"
echo "--------------------------------------------------------------------------------"

# Move to the correct location and create a local Git repo if it doesn't exist
BACKUP_DIR="$HOME/bak"

if [ ! -d "$BACKUP_DIR/.git" ]; then
    echo "--------------------------------------------------------------------------------"
    echo "Creating a local Git repo in $BACKUP_DIR for backups"
    echo "--------------------------------------------------------------------------------"
    cd "$BACKUP_DIR"
    git init
else
    cd "$BACKUP_DIR"
fi


echo "--------------------------------------------------------------------------------"
echo "Making a backup of some key files for you now, select more to add yourself below"
echo "--------------------------------------------------------------------------------"
#add file paths here before comp that you want backed up
files_to_backup=(
"/etc/ssh/sshd_config"
"/usr/bin/ls"
"/etc/passwd"
"/etc/shadow"
"/etc/group"
"/etc/pam.d"
#"/etc/iptables/rules.v4"
"/$HOME/.bash_history"
)

for file in "${files_to_backup[@]}"; do
    if [ -e "$file" ]; then
        name=$(basename "$file")
        sudo cp -r "$file" "$BACKUP_DIR/"
        sudo git add "$BACKUP_DIR/$name"
    else
        echo "Skipping $file (not found)"
    fi
done

git commit -m "auto bakup key files $(date '+%Y-%m-%d %H:%M:%S')"

echo "--------------------------------------------------------------------------------"
echo "Completed backup of key files"
echo "--------------------------------------------------------------------------------"

backup_files
