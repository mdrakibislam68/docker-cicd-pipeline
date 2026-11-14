# Security Policy & Architecture

## Security Overview

Security is a foundational pillar of this CI/CD pipeline. This project adheres to defense-in-depth principles across the software supply chain, container runtime configuration, and GitHub Actions orchestration.

> **Disclaimer:** While this pipeline implements current industry-standard hardening and least-privilege controls, no system is entirely invulnerable. Security is an ongoing process of monitoring, vulnerability patching, and auditing.

---

## 1. Pipeline Security Posture

### Least Privilege Permissions (RBAC)
- **Top-Level Default:** Restrictive workflow permissions default to `contents: read`. No global write permissions are granted.
- **Publish Scoping:** The `packages: write` privilege is strictly scoped to the `publish` job and only triggered on authorized, protected branches/tags.
- **Native GITHUB_TOKEN:** The pipeline uses ephemeral, installation-scoped `GITHUB_TOKEN` credentials provided automatically by GitHub Actions. Long-lived Personal Access Tokens (PATs) are avoided to eliminate token leakage risks.

### Fork & Pull Request Isolation
- Untrusted pull requests from forks run strictly within the unprivileged `pull_request` trigger context.
- The pipeline intentionally avoids `pull_request_target`, preventing untrusted pull requests from accessing repository secrets or executing privileged commands.
- Container image publication to GHCR is gated and never runs for pull requests.

### Action Version Pinning & Supply Chain
- Critical third-party actions are pinned to full-length, immutable commit SHAs with version comments (e.g., `actions/checkout@11bd7190... # v4.2.2`).
- Pinning commit SHAs mitigates supply chain risks associated with mutable Git tags that could be retargeted in the event of an upstream account compromise.
- No arbitrary remote scripts are fetched or executed via `curl | bash` patterns.

---

## 2. Container Runtime Hardening

### Non-Root Execution
- The Docker image is based on `nginxinc/nginx-unprivileged:1.27-alpine`.
- The container executes under unprivileged UID `101` (`nginx`), avoiding root privileges inside the container namespace.
- Unprivileged port `8080` is used instead of privileged port `80`.

### Minimal Attack Surface
- Built upon Alpine Linux for minimal package footprint and reduced Common Vulnerabilities and Exposures (CVEs).
- Unnecessary compilers, shells, and system utilities are excluded.
- The root filesystem can be mounted read-only (`--read-only`) in production runtimes.
- Docker security flag `no-new-privileges:true` is enforced in the Compose configuration to prevent privilege escalation.

### HTTP Response Hardening
Nginx response headers enforce modern web application security policies:
- `X-Frame-Options: SAMEORIGIN` (prevents clickjacking)
- `X-Content-Type-Options: nosniff` (prevents MIME type sniffing)
- `X-XSS-Protection: 1; mode=block` (legacy cross-site scripting filter)
- `Referrer-Policy: strict-origin-when-cross-origin` (protects referrer data)
- `Content-Security-Policy: default-src 'self' ...` (restricts script/style execution domains)
- `server_tokens off;` (suppresses exact Nginx version disclosure)

---

## 3. Known Limitations & Supply Chain Considerations

Clients and operators should consider the following residual operational risks:
1. **Upstream Base Image Vulnerabilities:** Base images (`nginx-unprivileged`) must be periodically rebuilt or updated to pull patched Alpine packages.
2. **Container Breakout in Shared Kernels:** Containers share the host Linux kernel; additional isolation (such as gVisor, Kata Containers, or isolated VMs) is recommended for multi-tenant environments.
3. **Registry Access Controls:** Ensure that GitHub repository package settings restrict who can pull or delete images in GHCR based on organizational needs.

---

## 4. Reporting a Security Vulnerability

If you discover a security vulnerability or misconfiguration in this repository:
1. **Do not open a public GitHub issue.**
2. Send an email to the repository maintainer or DevOps lead with detailed reproduction steps.
3. Include relevant proof-of-concept logs, Docker engine version, and impact analysis.
4. Vulnerability reports will be acknowledged within 48 hours, and patches will be coordinated prior to public disclosure.
