# arc-runner-custom-docker

<p align="center">
  <img src="assets/logo.png" alt="ARC Runner Scale Set" width="480" />
</p>

This repository shows **two distinct moving parts** you need for self‑hosted GitHub Actions runners on Kubernetes:

| Layer                         | Helm Chart                                                                                                                                 | What it Does                                        | Customization                                                                                        |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **1. ARC *Controller***       | [`ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller`](https://github.com/actions/actions-runner-controller) | Installs the CRDs & controller that manage runners. | **None** – use upstream image.                                                                       |
| **2. ARC *Runner Scale Set*** | [`ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set`](https://github.com/actions/actions-runner-controller-charts)     | Launches Pods that run `actions/runner`.            | **Yes** – we supply a *custom* Docker image containing Node.js 18, Playwright, and Robocorp **rcc**. |

The custom image is built on top of [`ghcr.io/actions/actions-runner:latest`](https://github.com/actions/runner/pkgs/container/runner) and adds:

* **[Playwright](https://playwright.dev/)** and its browser binaries.
* **[Robocorp Command Center CLI (rcc)](https://github.com/robocorp/rcc)** · [Docs](https://robocorp.com/docs/developer-tools/rcc).

---

---

## Table of Contents

* [Features](#features)
* [Prerequisites](#prerequisites)
* [Repository Structure](#repository-structure)
* [Installation and Deployment using `install.sh`](#installation-and-deployment-using-installsh)
* [Building the Custom Runner Image](#building-the-custom-runner-image)
* [Publishing to GitHub Container Registry (GHCR)](#publishing-to-github-container-registry-ghcr)
* [Kubernetes Secret for GHCR](#kubernetes-secret-for-ghcr)
* [Helm Deployment](#helm-deployment)
* [Configuration Reference](#configuration-reference)

  * [values.yaml](#valuesyaml)
  * [full\_values.yaml](#full_valuesyaml)
* [File Descriptions](#file-descriptions)
* [Contributing](#contributing)
* [License](#license)

---

## Features

* **Base Image –** [`ghcr.io/actions/actions-runner:latest`](https://github.com/actions/runner/pkgs/container/runner)
* **Node.js 18.x** pre‑installed
* **Playwright** (latest) + all required OS libs & browser binaries
* **Robocorp rcc** pre‑installed ([GitHub repo](https://github.com/robocorp/rcc) · [Docs](https://robocorp.com/docs/developer-tools/rcc))
* Helm‑configurable **ARC *Runner Scale Sets*** for horizontal scaling ([Chart repo](https://github.com/actions/actions-runner-controller-charts))

## Prerequisites

* **Docker** (for local image builds)
* **GitHub** PAT or GitHub App credentials
* **`kubectl`** + **Helm 3** (for Kubernetes deployments)
* Access to a **Kubernetes** cluster (K3s, Kind, EKS, etc.)

## Repository Structure

```text
.
├── README.md
├── yorko-io-arc-runner-shared.2025-06-02.private-key.pem  # GitHub App private key (expected by install.sh)
├── assets/
│   └── logo.png
├── docs/
│   ├── full_values.yaml      # Comprehensive Helm values for runner scale set
│   └── README.md             # Additional documentation
├── repos/
│   ├── builder-workflow/     # Config for a runner that can build other runner images
│   │   ├── README.md
│   │   └── values.yaml       # Helm values for the builder-workflow runner
│   ├── dind-custom-playwright/ # Example: Custom runner with Docker-in-Docker & Playwright
│   │   ├── Dockerfile
│   │   └── values.yaml
│   ├── fetch-repos/          # Example: Custom runner with Conda, Robocorp tools
│   │   ├── conda.yaml
│   │   ├── Dockerfile
│   │   ├── robot.yaml
│   │   └── values.yaml
│   └── ror/                  # Example: Another custom runner configuration
│       ├── Dockerfile
│       └── values.yaml
└── scripts/
    ├── create-ghcr-secret.sh # Script to create Kubernetes secret for private GHCR images
    └── install.sh            # Main installation and deployment script
```

## Installation and Deployment using `install.sh`

The primary method for deploying the ARC controller and runner scale sets is using the `scripts/install.sh` script.

**Prerequisites:**

*   **Docker:** For building images.
*   **Helm 3:** For deploying charts.
*   **`kubectl`:** Configured to your Kubernetes cluster.
*   **`yq`:** For parsing YAML files. The script will attempt to install `yq` if it's not found in your PATH.
*   **GitHub App Private Key:** A private key file named `yorko-io-arc-runner-shared.2025-06-02.private-key.pem` must be present in the root of this repository. This key is used by the `install.sh` script to create the `pre-defined-secret` for ARC's GitHub authentication.

**Usage:**

```bash
# Deploy without rebuilding images
./scripts/install.sh <repo-name>

# Deploy and rebuild the runner image
./scripts/install.sh <repo-name> build
```

**Examples:**

```bash
# Install controller and runners for the "fetch-repos" config
./scripts/install.sh fetch-repos

# Install and rebuild the "dind-custom-playwright" runner image before deployment
./scripts/install.sh dind-custom-playwright build
```

**What the script does:**

1.  **Builds and Pushes Image (if `build` flag is present):** As described above.
2.  **Installs ARC Controller:** Deploys or upgrades the `gha-runner-scale-set-controller` Helm chart from `oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller` into the `arc-systems` namespace (it will create the namespace if it doesn't exist).
3.  **Sets up Runner Namespace and Secrets:**
    *   Creates the `arc-runners` namespace if it doesn't exist.
    *   Creates a Kubernetes secret named `pre-defined-secret` in the `arc-runners` namespace. This secret contains the GitHub App credentials (App ID, Installation ID from the script, and the private key from the `.pem` file). This secret is used by the deployed runner scale set to authenticate with GitHub.
4.  **Deploys Runner Scale Set:** Deploys or upgrades the specified runner scale set using the `oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set` Helm chart. It applies configurations from the `repos/<repo-name>/values.yaml` file.

## Building the Custom Runner Image

Custom runner images allow you to pre-install necessary tools and dependencies for your GitHub Actions workflows.

*   **Recommended (via `install.sh`):**
    ```bash
    # Build and push a custom image for a specific runner config
    ./scripts/install.sh <repo-name> build
    # Example: ./scripts/install.sh ror build
    ```
*   **Manual Build (using Docker CLI):**
    ```bash
    # Determine OWNER/REPO from values.yaml
    OWNER_REPO=$(yq e '.githubConfigUrl' repos/<repo-name>/values.yaml | sed 's|https://github.com/||')
    IMAGE_TAG="ghcr.io/${OWNER_REPO}-runner:latest"
    docker build -t "$IMAGE_TAG" repos/<repo-name>/
    docker push "$IMAGE_TAG"
    ```

## Publishing to GitHub Container Registry (GHCR)

*   **Automated (via `install.sh`):** If you use the `build` flag with `scripts/install.sh <repo-name> build`, the script automatically pushes the built image to GHCR.
*   **Manual Push:** If you build the image manually, you can push it using the Docker CLI:
    ```bash
    # Ensure you are logged into GHCR: docker login ghcr.io
    # docker push YOUR_GHCR_IMAGE_TAG
    ```

## Kubernetes Secret for GHCR

If your custom runner images are stored in a **private** GitHub Container Registry (GHCR) repository, your Kubernetes cluster will need credentials to pull these images.

*   **Using `create-ghcr-secret.sh`:**
    ```bash
    # Run the helper script to generate a pull-secret YAML for GHCR
    ./scripts/create-ghcr-secret.sh
    ```
    The script will prompt for your GitHub username, a PAT or token with read:packages scope, and the target namespace. It outputs a file `ghcr-login-secret.yaml` which you can apply with:
    ```bash
    kubectl apply -f ghcr-login-secret.yaml
    ```

*   **Referencing the Secret:**
    Uncomment and configure the `imagePullSecrets` block in your runner values file (`repos/<repo-name>/values.yaml`):
    ```yaml
    template:
      spec:
        imagePullSecrets:
          - name: ghcr-login # Name of the secret created
    ```
