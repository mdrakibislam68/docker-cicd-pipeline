# Build-time and runtime metadata specification
# Base image: Official unprivileged Nginx on Alpine Linux for minimized attack surface
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Build arguments for versioning and traceability
ARG BUILD_VERSION="1.0.0"
ARG COMMIT_SHA="local-dev"
ARG BUILD_DATE="unknown"

# OCI standard container image labels
LABEL org.opencontainers.image.title="docker-cicd-pipeline" \
      org.opencontainers.image.description="Automated Docker CI/CD Pipeline with GitHub Actions and GHCR" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.revision="${COMMIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="Senior DevOps Engineer" \
      org.opencontainers.image.licenses="MIT"

# Set environment variables
ENV APPLICATION_VERSION="${BUILD_VERSION}" \
    COMMIT_HASH="${COMMIT_SHA}"

# Switch to root temporarily ONLY to copy assets and set strict non-root file ownership
USER root

# Copy custom hardened Nginx server configuration
COPY --chown=nginx:nginx nginx/default.conf /etc/nginx/conf.d/default.conf

# Copy static web application source
COPY --chown=nginx:nginx app/ /usr/share/nginx/html/

# Generate runtime version metadata file accessible by the web app
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${COMMIT_SHA}\",\"buildDate\":\"${BUILD_DATE}\"}" > /usr/share/nginx/html/version.json \
    && chown nginx:nginx /usr/share/nginx/html/version.json \
    && chmod 644 /usr/share/nginx/html/version.json

# Enforce least-privilege non-root execution (UID 101 = nginx)
USER 101

# Document internal listening port (unprivileged port > 1024)
EXPOSE 8080

# Automated container health probe
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/healthz || exit 1

# Default execution entrypoint from base image (runs nginx in foreground)
CMD ["nginx", "-g", "daemon off;"]
