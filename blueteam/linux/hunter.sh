#!/bin/bash

echo -e "\n-------- $(date) --------\n"

# Array to store files
files=()

# Detect Golang binaries
golang() {
    echo -e "\n----------\n> Golang <\n----------"
    mapfile -d $'\0' files < <(sudo find / -type f -executable -size +1M  \( ! -path '*snap*' ! -path '*container*' ! -path '*docker*' \) -print0 2>/dev/null)
    for i in "${files[@]}"; do
        if strings "$i" 2>/dev/null | grep -q 'go1\.'; then
            echo "Detected GO Binary : $i"
        fi
    done
}

# Detect kernel persistence
kits() {
    echo -e "\n----------\n> Kernel <\n----------"
    mapfile -d $'\0' files < <(sudo find / \( -path "/etc/init.d/*" -o -path "/etc/systemd/system/*" \) -print0 2>/dev/null)
    mapfile -d $'\0' files2 < <(sudo find /sys/module/ -iname "taint" -print0 2>/dev/null)

    for i in "${files[@]}"; do
        if strings "$i" 2>/dev/null | grep -E -q 'insmod|modprobe'; then
            echo "Detected Kernel Loading : $i"
        fi
    done

    for i in "${files2[@]}"; do
        if grep -E -q 'OE' "$i" 2>/dev/null; then
            echo "Detected Tainting : $i"
        fi
    done
}

# Detect modified system packages
integrity_check() {
    echo -e "\n----------\n> System Integrity Check <\n----------"
    if command -v debsums &>/dev/null; then
        echo "[Debian] Checking system packages..."
        sudo debsums -ac | tee /tmp/debsums_modified.log
    elif command -v dpkg &>/dev/null; then
        echo "[Ubuntu] Checking system packages with dpkg..."
        sudo dpkg -V | tee /tmp/dpkg_modified.log && for i in $(dpkg --get-selections | awk '{print $1}'); do sudo dpkg --verify $i; done
    elif command -v pacman &>/dev/null; then
        echo "[Arch] Checking system packages..."
        pacman -Qkk | grep 'missing\|warning' | tee /tmp/pacman_modified.log
    elif command -v rpm &>/dev/null; then
        echo "[RHEL] Checking system packages..."
        sudo rpm -Va | tee /tmp/rpm_modified.log
    else
        echo "No package integrity tool found."
    fi
}

# Detect hidden files and directories
hidden_files() {
    echo -e "\n----------\n> Hidden Files <\n----------"
    find / -name ".*" 2>/dev/null | grep -v "/\.\.$" | tee /tmp/hidden_files.log
}

# Check active network connections
network_activity() {
    echo -e "\n----------\n> Active Network Connections <\n----------"
    ss -tulpan | tee /tmp/network_connections.log
}

# Find SUID binaries (potential privilege escalation)
suid_binaries() {
    echo -e "\n----------\n> SUID Binaries <\n----------"
    find / -perm -4000 -type f 2>/dev/null | tee /tmp/suid_binaries.log
}

# Check crontabs for persistence
crontab_persistence() {
    echo -e "\n----------\n> Crontab Persistence <\n----------"
    for user in $(cut -f1 -d: /etc/passwd); do
        echo "Crontab for $user:"
        sudo crontab -l -u "$user" 2>/dev/null
    done | tee /tmp/crontabs.log
}




check_services() {
services="/etc/systemd/system"


find -L "$services" -type f -name "*.service" | while read service; do
    if [ -e "$service" ]; then
        echo -e "\n"
        echo "--------------------------------------------------------------------------------"
        echo "checking service $service"
        echo "--------------------------------------------------------------------------------"
        echo -e "\n"
        grep -E 'Description|ExecStart|ExecStartPre|User|Group' "$service"
    else
        echo "skipping service $service"
    fi
done
}






# User Menu
echo -ne "Enter Option (Default : Basic)\n1) Golang\n2) Kernel Persistence\n3) System Integrity\n4) Hidden Files\n5) Network Activity\n6) SUID Binaries\n7) systemd services\n8) Crontab Persistence\n9) All\n\n : "
read -r opt

case $opt in
    1) golang ;;
    2) kits ;;
    3) integrity_check ;;
    4) hidden_files ;;
    5) network_activity ;;
    6) suid_binaries ;;
    7) check_services ;;
    8) crontab_persistence ;;
    9) golang; kits; integrity_check; hidden_files; network_activity; suid_binaries; crontab_persistence; check_services ;;
    *) kits; golang ;;
esac
