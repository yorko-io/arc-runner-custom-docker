# Custom GitHub Actions Runner with Playwright & Robocorp

<p align="center">
  <img src="assets/logo.png" alt="Project Logo" width="500" />
</p>

This repository provides a **custom Docker image** and **Kubernetes deployment** setup for running **GitHub Actions self‑hosted runners** that come pre‑installed with:

* **[Playwright](https://playwright.dev/)** – for browser automation
* **[Robocorp Command Center CLI (rcc)](https://github.com/robocorp/rcc)** – Robocorp’s task‑automation toolchain

The image extends the official **[GitHub Actions Runner container](https://github.com/actions/runner)** and is designed to be deployed at scale via the **[Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller)** Helm chart with its runner‑**Scale Set** feature.

---

## Table of Contents

* [Features](#features)
* [Prerequisites](#prerequisites)
* [Repository Structure](#repository-structure)
* [Building the Docker Image](#building-the-docker-image)
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
├── Dockerfile                # Builds the custom runner image
├── create-ghcr-secret.sh     # Generates a Kubernetes secret for GHCR auth
├── values.yaml               # Minimal Helm values for a runner scale set
├── full_values.yaml          # Complete values reference w/ examples & comments
├── install.sh                # Installs ARC & the scale set via Helm
└── README.md                 # Project documentation (this file)
```

## Building the Docker Image

1. **Clone** the repo:

   ```bash
   git clone https://github.com/your-org/arc-runner-custom-docker.git
   cd arc-runner-custom-docker
   ```
2. **Build** locally:

   ```bash
   docker build -t ghcr.io/<your-org>/custom-arc-runner:latest .
   ```
3. *(Optional)* **Test** the toolchains:

   ```bash
   docker run --rm ghcr.io/<your-org>/custom-arc-runner:latest playwright --version
   docker run --rm ghcr.io/<your-org>/custom-arc-runner:latest rcc --version
   ```

## Publishing to GitHub Container Registry (GHCR)

1. **Login** to GHCR:

   ```bash
   echo $GHCR_PAT | docker login ghcr.io -u <your‑username> --password-stdin
   ```
2. **Tag & push**:

   ```bash
   docker tag custom-arc-runner:latest ghcr.io/<your-org>/custom-arc-runner:latest
   docker push ghcr.io/<your-org>/custom-arc-runner:latest
   ```

## Kubernetes Secret for GHCR

Allow the cluster to pull your image:

```bash
chmod +x create-ghcr-secret.sh
./create-ghcr-secret.sh   # generates ghcr-login-secret.yaml
kubectl apply -f ghcr-login-secret.yaml -n <runner-namespace>
```

## Helm Deployment

`install.sh` wraps Helm to install **ARC** *and* your **Scale Set**:

```bash
chmod +x install.sh
./install.sh
```

Under the hood it runs something equivalent to:

```bash
helm repo add arc https://actions-runner-controller.github.io/actions-runner-controller
helm upgrade --install arc arc/actions-runner-controller \
  --namespace arc-system --create-namespace

helm upgrade --install custom-runners \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace arc-runners -f values.yaml
```

---

## Configuration Reference

### values.yaml

A **minimal** scale‑set configuration – edit the placeholders:

```yaml
githubConfigUrl: "https://github.com/<your-org>/<your-repo>"
githubConfigSecret:
  github_token: "<YOUR_GITHUB_PAT>"
runnerScaleSetName: "custom-runner-scale-set"
containerMode:
  type: "dind"   # Docker‑in‑Docker

template:
  spec:
    containers:
      - name: runner
        image: ghcr.io/<your-org>/custom-arc-runner:latest
        imagePullPolicy: Always
        command: ["/home/runner/run.sh"]
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "4"
            memory: "8Gi"
```

### full\_values.yaml

Every configurable knob with comments:

```bash
cp full_values.yaml values.custom.yaml
helm upgrade --install custom-runners \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace arc-runners -f values.custom.yaml
```

---

## File Descriptions

| File                      | Purpose                                                       |
| ------------------------- | ------------------------------------------------------------- |
| **Dockerfile**            | Builds the custom runner image with Node.js, Playwright & rcc |
| **create-ghcr-secret.sh** | Generates a pull‑secret YAML for GHCR                         |
| **values.yaml**           | Quick‑start Helm values                                       |
| **full\_values.yaml**     | Fully‑documented values reference                             |
| **install.sh**            | Automates ARC + Scale Set install                             |

## Contributing

1. **Fork** the repo
2. `git checkout -b feature/<your-feature>`
3. Commit & push
4. **Open a PR**

---

## License

MIT – see the [LICENSE](LICENSE) file for details.
