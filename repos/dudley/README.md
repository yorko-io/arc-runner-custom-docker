# Dudley Custom Runner

This is a custom ARC runner configuration for building container images (specifically for the `dudleys-second-bedroom` repository).

## Features

The custom Docker image includes:
- **Podman** - For rootless container builds
- **Buildah** - Container image building tool
- **Skopeo** - Container image operations
- **BTRFS tools** - For advanced storage features
- **Fuse-overlayfs** - For rootless overlay filesystem

## Setup

### 1. Build the custom image

The custom image is automatically built by the GitHub Actions workflow when you push changes to `repos/dudley/Dockerfile`.

You can also manually trigger the build:
```bash
# Go to GitHub Actions and run the "Build Dudley Custom Runner Image" workflow
```

### 2. Update values.yaml

Once the image is built, update the image reference in `values.yaml`:

```yaml
containers:
  - name: runner
    image: ghcr.io/yorko-io/arc-runner-dudley-builder:latest
    imagePullPolicy: Always
```

### 3. Install/Update the runner

```bash
cd /path/to/arc-runner-custom-docker
./scripts/install.sh dudley
```

## Configuration

### Resources
- CPU: 2 cores requested, 4 cores limit
- Memory: 4Gi requested, 8Gi limit
- Storage: 50Gi ephemeral volume for builds

### Container Mode
- Type: `dind` (Docker-in-Docker)
- This enables the Docker daemon sidecar for container operations

## Usage

After installation, your GitHub Actions workflows in the `dudleys-second-bedroom` repository can use:

```yaml
runs-on: arc-runner-k8s
```

The runner will have all the tools needed for container image builds using buildah/podman.

## Troubleshooting

### Image pull errors
Make sure the image is public or you have configured `imagePullSecrets`:

```yaml
imagePullSecrets:
  - name: ghcr-login
```

### Storage issues
If you run out of space, increase the ephemeral volume size in `values.yaml`:

```yaml
resources:
  requests:
    storage: 100Gi  # Increase as needed
```
