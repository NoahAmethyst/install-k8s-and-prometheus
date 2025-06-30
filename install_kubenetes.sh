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

# Set Sealos version
echo "Getting latest Sealos version from GitHub..."
VERSION=$(curl -s https://api.github.com/repos/labring/sealos/releases/latest | grep -oE '"tag_name": "[^"]+"' | head -n1 | cut -d'"' -f4)
echo "Latest Sealos version is: $VERSION"

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

# Ask which Kubernetes installation to perform
echo "Choose Kubernetes installation type:"
echo "1) Single-node cluster"
echo "2) Multi-node cluster"
read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        echo "Installing single-node Kubernetes cluster..."
        sudo sealos run registry.cn-shanghai.aliyuncs.com/labring/kubernetes-docker:v1.28.0 \
            registry.cn-shanghai.aliyuncs.com/labring/helm:v3.9.4 \
            registry.cn-shanghai.aliyuncs.com/labring/calico:v3.24.1 --single
        ;;
    2)
        echo "Installing multi-node Kubernetes cluster..."
        MASTER_NODES=$(get_input "Enter master node IPs (comma separated)" "192.168.0.1")
        WORK_NODES=$(get_input "Enter worker node IPs (comma separated)" "192.168.0.2,192.168.0.3")
        CLUSTER_PASSWORD=$(get_input "Enter cluster password" "d93k6prHwYlH")

        sudo sealos run registry.cn-shanghai.aliyuncs.com/labring/kubernetes-docker:v1.28.0 \
            registry.cn-shanghai.aliyuncs.com/labring/helm:v3.9.4 \
            registry.cn-shanghai.aliyuncs.com/labring/calico:v3.24.1 \
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