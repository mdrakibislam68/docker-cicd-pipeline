#!/usr/bin/env bash
# ==============================================================================
# Script: local-build.sh
# Description: Builds the Docker image locally with traceable metadata.
# ==============================================================================

set -euo pipefail

# Text formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RESET="\033[0m"

echo -e "${BLUE}${BOLD}==> Starting Local Docker Build for docker-cicd-pipeline${RESET}"

# Determine project directory root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

# Extract build metadata
BUILD_VERSION="${BUILD_VERSION:-1.0.0}"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    COMMIT_SHA="$(git rev-parse --short HEAD)"
else
    COMMIT_SHA="local-dev"
fi
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

IMAGE_NAME="docker-cicd-pipeline"
LOCAL_TAG="${IMAGE_NAME}:local"
LATEST_TAG="${IMAGE_NAME}:latest"

echo -e "${YELLOW}Build Configuration:${RESET}"
echo "  - Version:    ${BUILD_VERSION}"
echo "  - Commit:     ${COMMIT_SHA}"
echo "  - Timestamp:  ${BUILD_DATE}"
echo "  - Image Tags: ${LOCAL_TAG}, ${LATEST_TAG}"

# Execute Docker Build
docker build \
    --file Dockerfile \
    --tag "${LOCAL_TAG}" \
    --tag "${LATEST_TAG}" \
    --build-arg BUILD_VERSION="${BUILD_VERSION}" \
    --build-arg COMMIT_SHA="${COMMIT_SHA}" \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    .

echo -e "\n${GREEN}${BOLD}✓ Docker image build completed successfully!${RESET}"
echo -e "${BLUE}Image details:${RESET}"
docker images --filter "reference=${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
