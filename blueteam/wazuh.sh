#!/bin/bash

# Pre-check root *before* setting pipefail
ensure_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "This script must be run with root privileges (sudo or as root)."
        exit 1
    fi
}
ensure_root

# Safety settings
set -euo pipefail

LOGFILE="/tmp/wazuh-install.log"
exec > >(tee -a "$LOGFILE") 2>&1

# Resource check
check_resources() {
    echo "Checking system resources..."
    CPU_COUNT=$(nproc)
    MEM_TOTAL_MB=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
    DISK_AVAIL_GB=$(df / | awk 'NR==2 {print int($4 / 1024 / 1024)}')

    echo "CPU cores: $CPU_COUNT"
    echo "Memory: ${MEM_TOTAL_MB}MB"
    echo "Disk space: ${DISK_AVAIL_GB}GB"

    if (( CPU_COUNT < 2 )); then
        echo "Requires at least 2 CPU cores."
        exit 1
    fi
    if (( MEM_TOTAL_MB < 2048 )); then
        echo "Requires at least 2GB RAM."
        exit 1
    fi
    if (( DISK_AVAIL_GB < 15 )); then
        echo "Requires at least 15GB of available disk space."
        exit 1
    fi

    echo "System resources sufficient."
}

# Detect OS
get_os() {
    echo "Detecting operating system..."
    OS_NAME=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
    case "$OS_NAME" in
        ubuntu) this_OS=1 ;;
        debian) this_OS=6 ;;
        fedora) this_OS=2 ;;
        centos) this_OS=3 ;;
        rhel)   this_OS=4 ;;
        oracle) this_OS=5 ;;
        *) echo "Unsupported OS: $OS_NAME" && exit 1 ;;
    esac
    echo "Detected OS: $OS_NAME"
}

# Install Docker Engine
install_docker() {
    echo "Installing Docker..."

    if [[ "$this_OS" -eq 1 || "$this_OS" -eq 6 ]]; then
        apt-get update -qq
        apt-get remove -y docker docker-engine docker.io containerd runc || true
        apt-get install -y ca-certificates curl gnupg lsb-release > /dev/null

        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/${OS_NAME}/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
          https://download.docker.com/linux/${OS_NAME} \
          $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
          | tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update -qq
        apt-get install -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin > /dev/null

    elif [[ "$this_OS" -ge 2 && "$this_OS" -le 5 ]]; then
        dnf remove -y docker* || true
        dnf install -y dnf-plugins-core > /dev/null

        REPO="docker-ce.repo"
        dnf config-manager --add-repo https://download.docker.com/linux/$OS_NAME/$REPO
        dnf install -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin > /dev/null
        systemctl enable --now docker
    fi

    echo "Docker installed"
}

# Set vm.max_map_count
configure_sysctl() {
    echo "Configuring vm.max_map_count..."
    grep -q '^vm.max_map_count' /etc/sysctl.conf \
        && sed -i 's/^vm.max_map_count=.*/vm.max_map_count=262144/' /etc/sysctl.conf \
        || echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
    sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count set to: $(sysctl -n vm.max_map_count)"
}

# Deploy Wazuh
install_wazuh() {
    echo "Deploying Wazuh..."
    cd /opt
    rm -rf wazuh-docker
    git clone --quiet https://github.com/wazuh/wazuh-docker.git -b v4.12.0
    cd wazuh-docker/single-node

    echo "Generating Wazuh certificates..."
    docker compose -f generate-indexer-certs.yml run --rm generator > /dev/null 2>&1

    echo "Starting Wazuh containers..."
    docker compose up -d > /dev/null
    sleep 10

    if ! curl -sk https://localhost/app > /dev/null; then
        echo "Initial connection failed. Retrying certificate generation..."
        docker compose down > /dev/null
        docker compose -f generate-indexer-certs.yml run --rm generator > /dev/null 2>&1
        docker compose up -d > /dev/null
        sleep 15
    fi
}

# Verify Wazuh
verify_wazuh() {
    echo "Verifying Wazuh dashboard..."
    if curl -sk https://localhost/app/ | grep -q Unauthorized; then
        echo "Wazuh dashboard is available at: https://localhost"
        echo "   Username: admin"
        echo "   Password: SecretPassword"
    else
        echo "Wazuh dashboard is not reachable. Check Docker logs."
    fi
}

# Main
main() {
    echo "Starting Wazuh deployment..."
    check_resources
    get_os
    install_docker
    configure_sysctl
    install_wazuh
    verify_wazuh
    echo "Wazuh installation complete!"
    echo "Log saved to: $LOGFILE"
}

main "$@"
