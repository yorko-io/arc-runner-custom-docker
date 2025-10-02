# Base on the official GitHub Actions Runner image
FROM ghcr.io/actions/actions-runner:2.328.0

# Switch to root for installations
USER root

# Install container build tools and dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    curl \
    wget \
    gnupg \
    ca-certificates \
    software-properties-common \
    apt-transport-https \
    btrfs-progs \
    fuse-overlayfs \
    slirp4netns \
    uidmap \
 && rm -rf /var/lib/apt/lists/*

# Install podman
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    podman \
    buildah \
    skopeo \
 && rm -rf /var/lib/apt/lists/*

# Configure podman for rootless operation
RUN mkdir -p /etc/containers \
 && echo "runner:1000:65536" > /etc/subuid \
 && echo "runner:1000:65536" > /etc/subgid

# Create podman storage configuration for runner user
RUN mkdir -p /home/runner/.config/containers \
 && cat > /home/runner/.config/containers/storage.conf <<EOF
[storage]
driver = "overlay"
runroot = "/home/runner/.local/share/containers/storage"
graphroot = "/home/runner/.local/share/containers/storage"

[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"
EOF

# Fix permissions
RUN chown -R runner:runner /home/runner/.config \
 && mkdir -p /home/runner/.local/share/containers/storage \
 && chown -R runner:runner /home/runner/.local/share

# Install additional useful tools
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    git \
    jq \
    unzip \
    zip \
 && rm -rf /var/lib/apt/lists/*

# Revert to the non-root runner user
USER runner

# Verify installations
RUN podman --version \
 && buildah --version \
 && skopeo --version
