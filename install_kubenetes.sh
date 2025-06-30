#!/bin/bash

# Function to ask yes/no question
ask_yes_no() {
    local prompt="$1 (y/n) "
    while true; do
        read -p "$prompt" yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to get input with default value
get_input() {
    local prompt="$1"
    local default="$2"
    local input
    read -p "$prompt [$default]: " input
    echo "${input:-$default}"
}

# Function to check if Sealos is installed and get current version
check_sealos_installed() {
    if command -v sealos &> /dev/null; then
        CURRENT_VERSION=$(sealos version --short 2>/dev/null || sealos version | head -n1 | awk '{print $3}')
        echo "Sealos is already installed (version: $CURRENT_VERSION)"
        return 0
    else
        echo "Sealos is not installed"
        return 1
    fi
}

# Function to install or update Sealos
install_or_update_sealos() {
    # Set Sealos version
    echo "Getting latest Sealos version from GitHub..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/labring/sealos/releases/latest | grep -oE '"tag_name": "[^"]+"' | head -n1 | cut -d'"' -f4)
    echo "Latest Sealos version is: $LATEST_VERSION"

    # Ask if in China to set proxy
    if ask_yes_no "Are you in China and need to use a proxy for GitHub?"; then
        export PROXY_PREFIX="https://ghfast.top"
        echo "Proxy set to $PROXY_PREFIX"
    fi

    # Install Sealos with yum(RPM)
    echo "Setting up labring yum repository..."
    sudo tee /etc/yum.repos.d/labring.repo << EOF
[fury]
name=labring Yum Repo
baseurl=https://yum.fury.io/labring/
enabled=1
gpgcheck=0
EOF

    echo "Cleaning yum cache and installing Sealos..."
    sudo yum clean all
    sudo yum install -y sealos
}

# Check if Sealos is installed
if check_sealos_installed; then
    if ask_yes_no "Do you want to check for updates and reinstall if needed?"; then
        install_or_update_sealos
    else
        echo "Using existing Sealos installation"
    fi
else
    echo "Sealos not found, installing..."
    install_or_update_sealos
fi

# Verify Sealos installation
if ! command -v sealos &> /dev/null; then
    echo "Error: Sealos installation failed. Please check the installation process."
    exit 1
fi

# Ask which Kubernetes installation to perform
echo "Choose Kubernetes installation type:"
echo "1) Single-node cluster"
echo "2) Multi-node cluster"
read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        echo "Installing single-node Kubernetes cluster..."
        sudo sealos run registry.cn-shanghai.aliyuncs.com/labring/kubernetes:v1.29.9 \
            registry.cn-shanghai.aliyuncs.com/labring/helm:v3.9.4 \
            registry.cn-shanghai.aliyuncs.com/labring/cilium:v1.13.4 --single
        ;;
    2)
        echo "Installing multi-node Kubernetes cluster..."
        MASTER_NODES=$(get_input "Enter master node IPs (comma separated)" "192.168.0.1")
        WORK_NODES=$(get_input "Enter worker node IPs (comma separated)" "192.168.0.2,192.168.0.3")
        CLUSTER_PASSWORD=$(get_input "Enter cluster password" "d93k6prHwYlH")

        sudo sealos run registry.cn-shanghai.aliyuncs.com/labring/kubernetes:v1.29.9 \
            registry.cn-shanghai.aliyuncs.com/labring/helm:v3.9.4 \
            registry.cn-shanghai.aliyuncs.com/labring/cilium:v1.13.4 \
            --masters "$MASTER_NODES" \
            --nodes "$WORK_NODES" \
            -p "$CLUSTER_PASSWORD"
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "Kubernetes installation completed!"