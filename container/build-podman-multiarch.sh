#!/bin/bash
set -e

VERSION="0.8.6"
REGISTRY="quay.io/masales"
IMAGE_NAME="mqttloader"
FULL_TAG="${REGISTRY}/${IMAGE_NAME}:${VERSION}"

# Detect if we're in container/ subdirectory and adjust context
SCRIPT_DIR=$(dirname "$0")
if [[ $(basename "$(pwd)") == "container" && -f "../build.gradle" ]]; then
    BUILD_CONTEXT="../"
    CONTAINERFILE_PATH="Containerfile"
elif [[ -f "build.gradle" ]]; then
    BUILD_CONTEXT="."
    CONTAINERFILE_PATH="container/Containerfile"
else
    echo "Error: Must run from project root or container/ directory"
    exit 1
fi

# Detect architecture and decide build strategy
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]]; then
    # ARM64 can emulate AMD64 better, do multi-arch
    PLATFORMS="linux/amd64,linux/arm64"
    BUILD_TYPE="Multi-Arch (ARM64 host)"
elif [[ "$ARCH" == "x86_64" ]]; then
    # AMD64 has issues with ARM64 emulation in Gradle, build only native
    PLATFORMS="linux/amd64"
    BUILD_TYPE="Native AMD64 only (avoids Gradle emulation issues)"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

echo "=== Building ${BUILD_TYPE} ${FULL_TAG} ==="
echo "Build context: ${BUILD_CONTEXT}"
echo "Target platforms: ${PLATFORMS}"

# Remove existing manifest
echo "Removing existing manifest..."
podman manifest rm ${FULL_TAG} 2>/dev/null || true

# Create new manifest
echo "Creating manifest..."
podman manifest create ${FULL_TAG}

# Build for detected platforms and add to manifest
echo "Building image for ${PLATFORMS}..."
podman buildx build --platform ${PLATFORMS} --no-cache --manifest ${FULL_TAG} -f ${CONTAINERFILE_PATH} ${BUILD_CONTEXT}

# Push manifest
echo "Pushing manifest..."
podman manifest push ${FULL_TAG}

echo "=== Multi-arch build complete! ==="
echo "Available at: ${FULL_TAG}"
