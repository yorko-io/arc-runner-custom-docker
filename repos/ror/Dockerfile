# Base on the official GitHub Actions Runner image
FROM ghcr.io/actions/actions-runner:2.324.0

# Switch to root for installations
USER root

# Install Node.js with minimal extras
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates \
 && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
 && apt-get update \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# Install Playwright and delegate OS deps + browsers
RUN npm install -g playwright \
 && npx playwright install-deps \
 && npx playwright install --with-deps

# Install rcc (Robocorp Command Center)
RUN curl -o rcc https://cdn.sema4.ai/rcc/releases/latest/linux64/rcc \
 && chmod a+x rcc \
 && mv rcc /usr/local/bin/

# Copy conda.yaml and robot.yaml to /workspace (or another directory rcc expects)
COPY conda.yaml /workspace/conda.yaml
COPY robot.yaml /workspace/robot.yaml

WORKDIR /workspace
RUN rcc holotree vars


# Revert to the non-root runner user
USER runner
