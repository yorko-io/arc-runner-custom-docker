#!/usr/bin/env bash
set -e

# Usage: ./install.sh <repo-dir> [build]
REPO_DIR=${1:?'Usage: $0 <repo-dir> [build]'}
BUILD_FLAG=${2:-}
VALUES_FILE="repos/$REPO_DIR/values.yaml"
DOCKERFILE="repos/$REPO_DIR/Dockerfile"

YQ_COMMAND=""

# Function to detect yq type and install if needed
detect_yq_type() {
    if command -v yq &> /dev/null; then
        # Check if it's the Go-based yq (mikefarah/yq) by testing the 'e' command
        if yq e --help &> /dev/null; then
            echo "go"
        # Check if it's the Python-based yq by testing jq-style syntax
        elif echo '{"test": "value"}' | yq -r .test &> /dev/null 2>&1; then
            echo "python"
        else
            echo "unknown"
        fi
    else
        echo "none"
    fi
}

# Function to find or install yq
setup_yq() {
    YQ_TYPE=$(detect_yq_type)
    
    case $YQ_TYPE in
        "go")
            YQ_COMMAND="yq"
            echo "Go-based yq (mikefarah/yq) found in PATH."
            return 0
            ;;
        "python")
            echo "Python-based yq found, but we need Go-based yq for this script."
            echo "Installing Go-based yq alongside existing Python yq..."
            install_go_yq
            return $?
            ;;
        "unknown")
            echo "Unknown yq version found. Installing Go-based yq..."
            install_go_yq
            return $?
            ;;
        "none")
            echo "No yq found. Installing both Python-based and Go-based yq..."
            install_python_yq
            install_go_yq
            return $?
            ;;
    esac
}

# Function to install Python-based yq
install_python_yq() {
    echo "Installing Python-based yq..."
    if command -v pip3 &> /dev/null; then
        pip3 install --user yq
    elif command -v pip &> /dev/null; then
        pip install --user yq
    else
        echo "Warning: pip not found, skipping Python yq installation"
        return 1
    fi
}

# Function to install Go-based yq (mikefarah/yq)
install_go_yq() {
    # 1. Try apt-get install first
    echo "Attempting to install Go-based yq via apt..."
    if sudo apt-get update && sudo apt-get install -y yq; then
        if yq e --help &> /dev/null; then
            YQ_COMMAND="yq"
            echo "Go-based yq installed successfully via apt."
            return 0
        else
            echo "apt installed yq but it's not the Go-based version. Downloading mikefarah/yq binary..."
        fi
    else
        echo "apt install failed. Downloading mikefarah/yq binary..."
    fi

    # 2. Download official binary to /usr/local/bin
    echo "Downloading Go-based yq (mikefarah/yq) binary to /usr/local/bin/yq-go..."
    if sudo curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" -o "/usr/local/bin/yq-go"; then
        sudo chmod +x "/usr/local/bin/yq-go"
        # Verify the downloaded binary
        if /usr/local/bin/yq-go --version &> /dev/null; then
            YQ_COMMAND="/usr/local/bin/yq-go"
            echo "Go-based yq downloaded and installed successfully to /usr/local/bin/yq-go."
            return 0
        else
            echo "Downloaded yq binary but it's not executable or failed verification."
        fi
    else
        echo "Failed to download Go-based yq binary."
    fi

    echo "Error: Go-based yq could not be installed. Please install yq manually."
    exit 1
}

# Call setup_yq early
setup_yq

if [ ! -f "$VALUES_FILE" ]; then
  echo "Values file not found: $VALUES_FILE"
  exit 1
fi

if [[ "$BUILD_FLAG" == "build" ]]; then
  echo "Building and pushing image for $REPO_DIR"
  GITHUB_URL=$(${YQ_COMMAND} e '.githubConfigUrl' "$VALUES_FILE")
  OWNER_REPO=${GITHUB_URL#https://github.com/}
  ORG=${OWNER_REPO%/*}
  REPO_NAME=${OWNER_REPO##*/}
  IMAGE="ghcr.io/${ORG}/${REPO_NAME}-runner:latest"
  if [ -f "$DOCKERFILE" ]; then
    docker build -t "$IMAGE" "repos/$REPO_DIR"
    docker push "$IMAGE"
  else
    echo "No Dockerfile found in repos/$REPO_DIR, skipping build."
  fi
fi

# Install ARC controller
NAMESPACE="arc-systems"
helm upgrade --install arc \
  --namespace "$NAMESPACE" --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --wait          # wait until the controller deployment is ready

# Ensure runner namespace and GHCR secret

# Find the latest .private-key.pem file in the current directory
PEM_FILE=$(ls -1t *.private-key.pem 2>/dev/null | head -n 1)
if [[ -z "$PEM_FILE" ]]; then
  echo "Error: No .private-key.pem file found in the current directory."
  exit 1
fi

kubectl create namespace arc-runners || true
kubectl create secret generic pre-defined-secret \
  --namespace=arc-runners  \
  --from-literal=github_app_id=1354710 \
  --from-literal=github_app_installation_id=69321446 \
  --from-literal=github_app_private_key="$(cat "$PEM_FILE")" || true

# Install runner scale set for the specified repo
RANGE_NAME=$(${YQ_COMMAND} e '.runnerScaleSetName' "$VALUES_FILE")
helm upgrade --install "$RANGE_NAME" \
  --namespace arc-runners --create-namespace \
  -f "$VALUES_FILE" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set