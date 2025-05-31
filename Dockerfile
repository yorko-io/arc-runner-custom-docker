# Base on the official GitHub Actions Runner image
FROM ghcr.io/actions/actions-runner:latest

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

# Revert to the non-root runner user
USER runner
