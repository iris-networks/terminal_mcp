#!/bin/bash

# Docker multi-architecture build script using buildx

set -e

# Configuration
IMAGE_NAME="terminator"
TAG="${TAG:-latest}"
PLATFORMS="linux/amd64,linux/arm64"
REGISTRY="${REGISTRY:-}"

echo "🐳 Building multi-architecture Docker images..."
echo "Image: ${IMAGE_NAME}:${TAG}"
echo "Platforms: ${PLATFORMS}"

# Create and use buildx builder if it doesn't exist
BUILDER_NAME="terminator-builder"

if ! docker buildx ls | grep -q "${BUILDER_NAME}"; then
    echo "Creating buildx builder: ${BUILDER_NAME}"
    docker buildx create --name "${BUILDER_NAME}" --driver docker-container --bootstrap
fi

echo "Using buildx builder: ${BUILDER_NAME}"
docker buildx use "${BUILDER_NAME}"

# Build arguments
BUILD_ARGS=""
if [ -n "${REGISTRY}" ]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}"
else
    FULL_IMAGE_NAME="${IMAGE_NAME}"
fi

# Build and push (or load for local use)
if [ "${PUSH:-false}" = "true" ] && [ -n "${REGISTRY}" ]; then
    echo "Building and pushing to registry..."
    docker buildx build \
        --platform "${PLATFORMS}" \
        --tag "${FULL_IMAGE_NAME}:${TAG}" \
        --tag "${FULL_IMAGE_NAME}:latest" \
        --push \
        ${BUILD_ARGS} \
        .
else
    echo "Building for local use..."
    # For local builds, we can only build one platform at a time
    for platform in $(echo ${PLATFORMS} | tr ',' ' '); do
        platform_tag=$(echo $platform | sed 's/\//-/g')
        echo "Building for platform: ${platform}"
        docker buildx build \
            --platform "${platform}" \
            --tag "${FULL_IMAGE_NAME}:${TAG}-${platform_tag}" \
            --load \
            ${BUILD_ARGS} \
            .
    done
fi

echo "✅ Multi-architecture build completed!"

if [ "${PUSH:-false}" = "true" ] && [ -n "${REGISTRY}" ]; then
    echo "📦 Images pushed to: ${FULL_IMAGE_NAME}:${TAG}"
else
    echo "📦 Local images built:"
    for platform in $(echo ${PLATFORMS} | tr ',' ' '); do
        platform_tag=$(echo $platform | sed 's/\//-/g')
        echo "  - ${FULL_IMAGE_NAME}:${TAG}-${platform_tag}"
    done
fi

echo ""
echo "Usage examples:"
echo "# Run AMD64 image:"
echo "docker run --rm -p 8080:8080 ${FULL_IMAGE_NAME}:${TAG}-linux-amd64 --http --port 8080"
echo ""
echo "# Run ARM64 image:"
echo "docker run --rm -p 8080:8080 ${FULL_IMAGE_NAME}:${TAG}-linux-arm64 --http --port 8080"
echo ""
echo "# Push to registry:"
echo "REGISTRY=your-registry.com PUSH=true ./build-docker.sh"