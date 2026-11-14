# Automated Docker CI/CD Pipeline with GitHub Actions and GHCR

[![CI/CD Pipeline](https://github.com/mdrakibislam68/docker-cicd-pipeline/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/mdrakibislam68/docker-cicd-pipeline/actions/workflows/ci-cd.yml)
[![Docker Image](https://img.shields.io/badge/docker-unprivileged--alpine-blue?logo=docker)](https://hub.docker.com/r/nginxinc/nginx-unprivileged)
[![Registry](https://img.shields.io/badge/registry-GHCR-blue?logo=github)](https://github.com/mdrakibislam68/docker-cicd-pipeline/pkgs/container/docker-cicd-pipeline)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Security: Least Privilege](https://img.shields.io/badge/security-least--privilege-green.svg)](SECURITY.md)

> **DevOps Portfolio Project:** A production-grade, secure, and reproducible Continuous Integration and Continuous Delivery (CI/CD) pipeline built with **GitHub Actions**, **Docker**, **Docker Compose**, **Nginx Unprivileged**, and **GitHub Container Registry (GHCR)**.

---

## 📌 Executive Summary & Business Value

In modern software delivery, manual deployments and untested container builds lead to downtime, configuration drift, and security vulnerabilities. This project demonstrates an enterprise-grade automated pipeline designed to solve these challenges:

- **Zero Unverified Deployments:** No container image reaches the registry unless it passes static analysis, configuration validation, and live container smoke tests.
- **Fast Feedback Loop (< 2 Minutes):** Developers receive rapid automated feedback on every pull request and commit.
- **Immutable & Traceable Artifacts:** Every container published to GHCR is tagged with its Git commit SHA, branch name, semantic version, and standard OCI labels.
- **Defense-in-Depth Security:** Employs non-root unprivileged container runtimes, least-privilege GitHub Actions tokens (`GITHUB_TOKEN`), and immutable action SHA pinning.

---

## 🔄 Understanding CI vs. CD in This Architecture

A frequent point of confusion in DevOps implementations is the distinction between **Continuous Integration (CI)** and **Continuous Delivery / Deployment (CD)**:

| Attribute | Continuous Integration (CI) | Continuous Delivery (CD) | Continuous Deployment |
| :--- | :--- | :--- | :--- |
| **Primary Goal** | Validate code changes and detect regressions early. | Package and publish production-ready, release-verified artifacts. | Automatically release changes directly into end-user production environments. |
| **Execution Trigger** | Every Pull Request and commit push on any branch. | Merged commits into protected branches (`main`) or Version Tags (`v*.*.*`). | Automated trigger following passing CD pipeline stages. |
| **Pipeline Jobs** | Linters, syntax checks, unit tests, ephemeral container smoke tests. | Registry authentication, multi-platform image build, multi-tagging, GHCR push. | Blue/Green or Canary deployment to Kubernetes/ECS/VPS. |
| **Artifact Output** | Ephemeral test results, coverage reports, test logs. | Signed, immutable OCI container images in GHCR ready for deployment. | Live running service in production. |

> **Scope Note:** This project implements **Continuous Integration (CI)** and **Continuous Delivery (CD)** up to container artifact publishing in GitHub Container Registry. It intentionally avoids claiming automatic VPS deployment unless real production infrastructure is provisioned and monitored.

---

## 🏗️ Architecture & Pipeline Workflow

```
Developer Push / Pull Request
             |
             v
   GitHub Actions Runner
             |
   +---------+-----------------------------------------+
   | JOB A: Validate (Static Analysis & Syntax Checks) |
   | - Docker Compose specification validation         |
   | - Nginx configuration syntax check (nginx -t)     |
   | - Bash scripts syntax check (bash -n)             |
   | - Python test suite compilation (py_compile)      |
   | - Dockerfile linting (Hadolint)                   |
   +---------+-----------------------------------------+
             | (Pass)
             v
   +---------+-----------------------------------------+
   | JOB B: Test (Container Build & Smoke Suite)       |
   | - Ephemeral Docker container build                |
   | - Container initialization & health probe check   |
   | - Python automated HTTP & security header tests   |
   | - Custom 404/50x error routing verification       |
   | - Guaranteed teardown on success or failure       |
   +---------+-----------------------------------------+
             |
             +----[ Pull Request? ]-----> Pipeline Completes (Zero Image Published)
             |
             | (Push to main OR Version Tag)
             v
   +---------+-----------------------------------------+
   | JOB C: Publish (Continuous Delivery to GHCR)      |
   | - GitHub Actions GITHUB_TOKEN authentication      |
   | - Docker Buildx multi-tag generation              |
   |   • sha-<commit>  • main  • vX.Y.Z  • latest      |
   | - OCI standard metadata and provenance injection  |
   | - GitHub Actions layer cache (type=gha)           |
   | - Push immutable image to ghcr.io                 |
   +---------------------------------------------------+
             |
             v
   Versioned Image Ready for Production Orchestration
```

---

## 📂 Repository Structure

```text
docker-cicd-pipeline/
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # Enterprise 3-stage GitHub Actions workflow
├── app/
│   ├── index.html             # Responsive DevOps dashboard landing page
│   ├── 404.html               # Custom 404 Not Found error page
│   ├── 50x.html               # Custom 50x Internal Server Error page
│   └── assets/
│       ├── style.css          # Modern CSS design system
│       └── app.js             # Client-side healthcheck probe & uptime counter
├── nginx/
│   └── default.conf           # Hardened Nginx unprivileged configuration
├── tests/
│   └── test_deployment.py     # Python standard library automated smoke test suite
├── scripts/
│   ├── local-build.sh         # Local Docker image build script with metadata
│   └── local-test.sh          # End-to-end local test & validation orchestrator
├── .dockerignore              # Prevents unnecessary files from entering build context
├── .gitignore                # Git ignore rules for clean repo hygiene
├── compose.yaml               # Docker Compose v2 specification
├── Dockerfile                 # Multi-stage, unprivileged Nginx Dockerfile
├── LICENSE                    # MIT Open Source License
├── README.md                  # Comprehensive portfolio documentation
└── SECURITY.md                # Security policy, least-privilege, and threat model
```

---

## ⚙️ GitHub Actions Workflow Breakdown

The workflow is defined in [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml) with strict separation of concerns across three discrete jobs:

### 1. Job A: `validate`
- **Scope:** Fast, non-destructive static analysis.
- **Docker Compose:** Validated using `docker compose config --quiet` to catch YAML formatting or schema mismatches.
- **Nginx Configuration:** Validated via an isolated Nginx container running `nginx -t -q` against `nginx/default.conf`.
- **Shell Scripts:** Checked using `bash -n` to catch shell syntax bugs before runtime.
- **Python Tests:** Compiled with `python3 -m py_compile` to prevent runtime syntax exceptions.
- **Dockerfile Linting:** Scanned with `hadolint/hadolint-action` against containerization best practices.

### 2. Job B: `test`
- **Scope:** Live container smoke testing in an ephemeral test environment.
- **Builds Container:** Packages image with ephemeral build metadata.
- **Container Health Check:** Spawns the container and polls `docker inspect` until the Docker `HEALTHCHECK` passes.
- **Python Smoke Test Suite:** Executes [`tests/test_deployment.py`](tests/test_deployment.py) against `http://127.0.0.1:8080`:
  - `test_01_homepage_status_code`: Asserts HTTP 200 OK and `text/html`.
  - `test_02_homepage_content_assertions`: Verifies required branding and architecture elements.
  - `test_03_health_endpoint_contract`: Validates `/healthz` JSON schema and `status: "healthy"`.
  - `test_04_security_headers`: Asserts `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, `Content-Security-Policy`, and version token masking.
  - `test_05_static_assets_serving`: Verifies CSS/JS assets are served with correct MIME types.
  - `test_06_custom_404_error_page`: Tests that non-existent routes return HTTP 404 with custom error template.
- **Resilient Cleanup:** Employs `if: always()` to stop and remove containers cleanly even if assertions fail.

### 3. Job C: `publish`
- **Scope:** Secure delivery to GitHub Container Registry (GHCR).
- **Access Control:** Strictly restricted to pushes on `main` and release tags (`v*.*.*`). Pull requests cannot trigger image publishing.
- **Authentication:** Uses GitHub's built-in `GITHUB_TOKEN` with granular `packages: write` permissions.
- **Tagging Strategy:**
  - `sha-<commit>`: Immutable short commit SHA for auditability.
  - `main`: Reflects the current head of the main branch.
  - `vX.Y.Z` & `vX.Y`: Semantic versioning when a Git tag is pushed.
  - `latest`: Applied only on default branch or release tags.
- **Build Cache:** Employs GitHub Actions cache backend (`type=gha`) to dramatically accelerate subsequent builds.

---

## 🚀 Local Development & Testing Guide

You can run the entire CI/CD validation and smoke test lifecycle locally before pushing code to GitHub.

### Prerequisites
- Docker Engine & Docker Compose (v2.20+)
- Python 3.8+ (Standard Library only — no `pip install` required)
- Bash shell (Linux / macOS / WSL2)

### 1. Run Complete Local CI/CD Pipeline
The `local-test.sh` script mirrors the exact steps performed by GitHub Actions:
```bash
# Clone the repository
git clone https://github.com/mdrakibislam68/docker-cicd-pipeline.git
cd docker-cicd-pipeline

# Run all validations, image build, container spawn, and smoke tests
./scripts/local-test.sh
```

**Expected Output:**
```text
====================================================
  Docker CI/CD Pipeline - Local Test & Validation   
====================================================

[STAGE 1/3] Static Validation & Syntax Checks
  --> Checking Docker Compose syntax...
      ✓ Compose configuration is valid.
  --> Checking Nginx configuration syntax with container test...
      ✓ Nginx configuration syntax is valid.
  --> Checking Shell script syntax (bash -n)...
      ✓ All shell scripts passed syntax inspection.
  --> Checking Python test suite syntax (py_compile)...
      ✓ Python test files compiled successfully.

[STAGE 2/3] Building Container Image
✓ Docker image build completed successfully!

[STAGE 3/3] Starting Container and Running Smoke Tests
  --> Spawning application via Docker Compose...
  --> Waiting for container health status to report healthy...
      ✓ Container reported healthy after 5s.
  --> Running Python Automated Smoke Test Suite...
test_01_homepage_status_code ... ok
test_02_homepage_content_assertions ... ok
test_03_health_endpoint_contract ... ok
test_04_security_headers ... ok
test_05_static_assets_serving ... ok
test_06_custom_404_error_page ... ok

✓ All deployment smoke tests passed.
==> Cleaning up test environment...
✓ All local CI/CD tests PASSED successfully!
```

### 2. Manual Docker Compose Execution
To run the application locally in the background:
```bash
docker compose up -d
```
Visit **http://localhost:8080** in your web browser.

To check container health status:
```bash
docker compose ps
curl -i http://localhost:8080/healthz
```

To stop and remove containers:
```bash
docker compose down
```

---

## 📦 Pulling & Running the Published Container Image

Once published to GitHub Container Registry, any team member or deployment server can pull and run the verified container image:

### 1. Registry Authentication (If Image is Private)
```bash
echo $CR_PAT | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

### 2. Pull Specific Tags
```bash
# Pull the latest stable release
docker pull ghcr.io/mdrakibislam68/docker-cicd-pipeline:latest

# Pull by specific semantic version
docker pull ghcr.io/mdrakibislam68/docker-cicd-pipeline:v1.0.0

# Pull by specific commit SHA
docker pull ghcr.io/mdrakibislam68/docker-cicd-pipeline:sha-$(git rev-parse --short HEAD)
```

### 3. Run Container with Security Hardening
```bash
docker run -d \
  --name web-app \
  -p 8080:8080 \
  --security-opt no-new-privileges:true \
  --restart unless-stopped \
  ghcr.io/mdrakibislam68/docker-cicd-pipeline:latest
```

---

## 🔒 Security Best Practices Implemented

1. **Non-Root Execution:** The application runs inside Docker under non-root UID `101` (`nginx`).
2. **Minimal Permissions:** GitHub Actions workflow sets top-level `permissions: contents: read`. The `packages: write` permission is granted strictly to the publish job.
3. **No Secret Leaks:** Built-in `GITHUB_TOKEN` is used for GHCR authentication; no long-lived personal access tokens (PATs) or hardcoded credentials exist.
4. **Action SHA Pinning:** All third-party GitHub Actions are pinned to full commit SHAs with version comments to prevent supply-chain attacks.
5. **No `pull_request_target`:** Untrusted forks cannot execute malicious code against internal repository secrets.
6. **Detailed Security Policy:** Read [`SECURITY.md`](SECURITY.md) for vulnerability disclosure procedures and supply-chain analysis.

---

## 💼 Hire a Senior DevOps / CI/CD Architect

Looking to automate your development workflows, containerize legacy applications, or build bulletproof CI/CD pipelines for your team?

**Core Competencies:**
- **CI/CD Pipelines:** GitHub Actions, GitLab CI, Jenkins, ArgoCD, CircleCI.
- **Containerization & Orchestration:** Docker, Docker Compose, Kubernetes, Helm.
- **Cloud Infrastructure:** AWS (ECS, EKS, EC2, S3), GCP, DigitalOcean.
- **Infrastructure as Code (IaC):** Terraform, Ansible.
- **Security & Compliance:** Container scanning, least-privilege IAM, secret management (Vault).

📩 **Available for freelance contracts on Upwork.** Let's discuss your project requirements!

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
