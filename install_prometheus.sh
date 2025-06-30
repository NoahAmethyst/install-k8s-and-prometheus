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

# Function to check if Kubernetes is available
check_k8s() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl could not be found. Please install Kubernetes first."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        echo "Cannot connect to a Kubernetes cluster. Please ensure your cluster is running and configured."
        exit 1
    fi
}

# Function to replace github.com with kkgithub.com in URL
replace_github_url() {
    local url="$1"
    echo "$url" | sed 's/github.com/kkgithub.com/'
}

# Main script
echo "Kube-Prometheus installation script"
echo "----------------------------------"

# Check if Kubernetes is available
check_k8s

# Ask before cloning repository
if ask_yes_no "Do you want to clone the kube-prometheus repository from GitHub?"; then
    GIT_URL="https://github.com/prometheus-operator/kube-prometheus.git"

    if ask_yes_no "Do you want to use China mirror (replace github.com with kkgithub.com)?"; then
        GIT_URL=$(replace_github_url "$GIT_URL")
        echo "Using China mirror URL: $GIT_URL"
    else
        echo "Using original GitHub URL: $GIT_URL"
    fi

    echo "Cloning kube-prometheus repository..."
    git clone "$GIT_URL"
    if [ $? -ne 0 ]; then
        echo "Failed to clone repository. Please check your network connection."
        exit 1
    fi
else
    echo "Skipping repository clone."
    exit 0
fi

cd kube-prometheus || exit

# Explain what will happen next
echo "The kube-prometheus installation will now proceed in 3 steps:"
echo "1. Create namespace and CRDs using server-side apply"
echo "2. Wait for CRDs to be established"
echo "3. Apply all remaining manifests"

if ask_yes_no "Do you want to continue with the installation?"; then
    echo "Applying setup manifests with server-side apply..."
    kubectl apply --server-side -f manifests/setup

    echo "Waiting for CRDs to be established..."
    kubectl wait \
        --for condition=Established \
        --all CustomResourceDefinition \
        --namespace=monitoring

    echo "Applying all remaining manifests..."
    kubectl apply -f manifests/
else
    echo "Installation aborted by user."
    exit 0
fi

# Ask about network policy deletion
if ask_yes_no "Do you want to delete all network policies in the monitoring namespace?"; then
    echo "Deleting network policies..."
    kubectl delete networkpolicy --all -n monitoring
else
    echo "Skipping network policy deletion."
fi

echo "Installation complete!"