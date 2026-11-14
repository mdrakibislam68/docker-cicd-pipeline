#!/usr/bin/env bash
# ==============================================================================
# Script: local-test.sh
# Description: Executes complete local CI validation and smoke testing pipeline.
# ==============================================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo -e "${BLUE}${BOLD}====================================================${RESET}"
echo -e "${BLUE}${BOLD}  Docker CI/CD Pipeline - Local Test & Validation   ${RESET}"
echo -e "${BLUE}${BOLD}====================================================${RESET}"

# Cleanup handler to ensure zero orphaned containers
cleanup() {
    local exit_code=$?
    echo -e "\n${YELLOW}==> Cleaning up test environment...${RESET}"
    docker compose down -v --remove-orphans >/dev/null 2>&1 || true
    if [ "${exit_code}" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✓ All local CI/CD tests PASSED successfully!${RESET}"
    else
        echo -e "${RED}${BOLD}✗ Pipeline validation FAILED with exit code ${exit_code}!${RESET}"
    fi
    exit "${exit_code}"
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# Stage 1: Validation
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}[STAGE 1/3] Static Validation & Syntax Checks${RESET}"

echo -e "  --> Checking Docker Compose syntax..."
docker compose config --quiet
echo -e "      ${GREEN}✓ Compose configuration is valid.${RESET}"

echo -e "  --> Checking Nginx configuration syntax with container test..."
docker run --rm --entrypoint nginx \
    -v "${PROJECT_ROOT}/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro" \
    nginxinc/nginx-unprivileged:1.27-alpine -t -q
echo -e "      ${GREEN}✓ Nginx configuration syntax is valid.${RESET}"

echo -e "  --> Checking Shell script syntax (bash -n)..."
bash -n "${PROJECT_ROOT}/scripts/local-build.sh"
bash -n "${PROJECT_ROOT}/scripts/local-test.sh"
echo -e "      ${GREEN}✓ All shell scripts passed syntax inspection.${RESET}"

echo -e "  --> Checking Python test suite syntax (py_compile)..."
python3 -m py_compile "${PROJECT_ROOT}/tests/test_deployment.py"
echo -e "      ${GREEN}✓ Python test files compiled successfully.${RESET}"

# ------------------------------------------------------------------------------
# Stage 2: Container Image Build
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}[STAGE 2/3] Building Container Image${RESET}"
"${PROJECT_ROOT}/scripts/local-build.sh"

# ------------------------------------------------------------------------------
# Stage 3: Deployment & Smoke Testing
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}[STAGE 3/3] Starting Container and Running Smoke Tests${RESET}"
echo -e "  --> Spawning application via Docker Compose..."
docker compose up -d

echo -e "  --> Waiting for container health status to report healthy..."
CONTAINER_NAME="docker-cicd-pipeline-web"
MAX_WAIT=25
WAIT_COUNT=0
HEALTH_STATUS="starting"

while [ "${WAIT_COUNT}" -lt "${MAX_WAIT}" ]; do
    HEALTH_STATUS="$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}' "${CONTAINER_NAME}" 2>/dev/null || echo "starting")"
    if [ "${HEALTH_STATUS}" = "healthy" ]; then
        echo -e "      ${GREEN}✓ Container reported healthy after ${WAIT_COUNT}s.${RESET}"
        break
    fi
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ "${HEALTH_STATUS}" != "healthy" ]; then
    echo -e "${RED}✗ Container failed to reach healthy state within ${MAX_WAIT}s. Current state: ${HEALTH_STATUS}${RESET}"
    echo -e "${YELLOW}Container logs:${RESET}"
    docker logs "${CONTAINER_NAME}"
    exit 1
fi

echo -e "\n  --> Running Python Automated Smoke Test Suite..."
python3 "${PROJECT_ROOT}/tests/test_deployment.py" --url "http://127.0.0.1:8080"
echo -e "      ${GREEN}✓ All deployment smoke tests passed.${RESET}"
