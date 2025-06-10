#!/usr/bin/env bash
set -e

# Usage: ./install.sh <repo-dir> [build]
REPO_DIR=${1:?'Usage: $0 <repo-dir> [build]'}
BUILD_FLAG=${2:-}
VALUES_FILE="repos/$REPO_DIR/values.yaml"
DOCKERFILE="repos/$REPO_DIR/Dockerfile"

YQ_COMMAND=""

# Function to find or install yq
setup_yq() {
    # 1. Check if yq is already in PATH
    if command -v yq &> /dev/null; then
        YQ_COMMAND="yq"
        echo "yq found in PATH."
        return 0
    fi

    # 2. If not in PATH, try apt-get install (requires sudo)
    echo "yq not found in PATH, attempting to install via apt..."
    if sudo apt-get update && sudo apt-get install -y yq; then
        if command -v yq &> /dev/null; then # Re-check PATH
            YQ_COMMAND="yq"
            echo "yq installed successfully via apt and found in PATH."
            return 0
        else
            echo "apt install reported success, but yq still not found in PATH. Proceeding to binary download."
        fi
    else
        echo "apt install failed. Proceeding to binary download."
    fi

    # 3. If still not available, download official binary to /usr/local/bin
    echo "Attempting to download yq official binary to /usr/local/bin/yq..."
    if sudo curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" -o "/usr/local/bin/yq"; then
        sudo chmod +x "/usr/local/bin/yq"
        # Verify the downloaded binary
        if yq --version &> /dev/null; then # yq should be in PATH now
            YQ_COMMAND="yq"
            echo "yq downloaded and installed successfully to /usr/local/bin/yq."
            return 0
        else
            echo "Downloaded yq binary to /usr/local/bin/yq but it's not executable or failed verification."
        fi
    else
        echo "Failed to download yq binary to /usr/local/bin/yq."
    fi

    echo "Error: yq could not be installed or found. Please install yq manually."
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
kubectl create namespace arc-runners || true
kubectl create secret generic pre-defined-secret \
  --namespace=arc-runners  \
  --from-literal=github_app_id=1354710 \
  --from-literal=github_app_installation_id=69321446 \
  --from-literal=github_app_private_key="$(cat yorko-io-arc-runner-shared.2025-06-02.private-key.pem)" || true

# Install runner scale set for the specified repo
RANGE_NAME=$(${YQ_COMMAND} e '.runnerScaleSetName' "$VALUES_FILE")
helm upgrade --install "$RANGE_NAME" \
  --namespace arc-runners --create-namespace \
  -f "$VALUES_FILE" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set