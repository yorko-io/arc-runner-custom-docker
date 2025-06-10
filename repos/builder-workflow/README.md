# Builder Workflow Runner

This directory contains the configuration for the GitHub Actions workflow runner that builds and pushes custom runner images for other repositories.

- **values.yaml**: Helm values for deploying the builder workflow runner. Uses containerMode: dind (Docker-in-Docker).
- **No Dockerfile**: This runner is intended to run workflows, not to build a custom image for itself.

## Usage

This runner is used by the `.github/workflows/build-image.yml` workflow to build and push images for any specified repo directory.
