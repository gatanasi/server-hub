# Developer Context & Instructions

This file documents the architectural context, workflows, and conventions for the `server-hub` repository. Use this as your primary reference when working on this codebase.

## 1. Project Overview

**Server Hub** is an Infrastructure-as-Code (IaC) repository managing a home/private server environment. It implements a **GitOps** workflow where changes to the `main` branch trigger automated deployments of Docker-based applications to target VMs.

### Core Technologies
- **Orchestration:** Ansible (playbooks run on `deployer.vm`).
- **Containerization:** Docker & Docker Compose (v2).
- **Secrets Management:** SOPS with `age` encryption.
- **Infrastructure:** Proxmox VE (managed via scripts in `proxmox/`).
- **CI/CD:** GitHub Actions (triggers deployments via SSH to `deployer.vm`).

## 2. Architecture & Workflow

The system follows a strict GitOps model:

1.  **Code Change:** User pushes to `main`.
2.  **CI Trigger:** GitHub Action (`deploy.yml`) runs.
3.  **Secure Handoff:** Runner SSHs to `deployer.vm` using a forced-command key.
4.  **Deployment:** `deployer.vm` runs Ansible playbooks to:
    -   Decrypt secrets (`.env.enc` -> `.env`).
    -   Deploy containers to Target VMs (`n8n.vm`, `odoo.vm`, etc.).
    -   Verify health and rollback on failure.

### Key Directories
-   `ansible/`: Ansible playbooks, roles, and inventory.
    -   `inventory/production.yml`: **Source of Truth** for app-to-host mapping.
    -   `playbooks/deploy-docker-app.yml`: Main deployment logic.
-   `docker/`: Application definitions. Each subdirectory (e.g., `docker/n8n/`) contains:
    -   `compose.yaml`: Service definition.
    -   `.env.enc`: Encrypted secrets (SOPS).
-   `deploy/`: Shell scripts serving as the glue between CI and Ansible.
    -   `trigger.sh`: Dispatcher script (entry point for CI).
-   `proxmox/`: Scripts for VM provisioning and management.

## 3. Operational Guidelines

### 3.1. Working with Secrets (CRITICAL)
-   **NEVER** commit plain-text `.env` files.
-   **ALWAYS** use `.env.enc` encrypted with SOPS/age.
-   **To edit secrets:**
    ```bash
    sops --input-type dotenv --output-type dotenv .env.enc
    ```
-   **To create new secrets:**
    ```bash
    sops --input-type dotenv --output-type dotenv -e .env > .env.enc
    ```

### 3.2. Adding a New Application
1.  **Create Directory:** `mkdir docker/<app-name>`
2.  **Define Service:** Create `docker/<app-name>/compose.yaml`.
    -   **Requirement:** Must include `healthcheck` block for rollback to function.
3.  **Handle Secrets:** Create `.env.enc` if environment variables are needed.
4.  **Update Inventory:** Add `<app-name>` to the `managed_apps` list of the target host in `ansible/inventory/production.yml`.

### 3.3. Manual Deployment
While GitOps is the default, you can trigger deployments manually from the `deployer.vm` (or via the `deploy/` scripts if you have access):

```bash
# Deploy a specific app
./deploy/trigger-deploy.sh <app-name>
```

## 4. Development Standards

### Ansible
-   **Idempotency:** All tasks must be idempotent. Rerunning a playbook should not break anything or restart services unnecessarily.
-   **Variables:** Prefer passing variables via `-e` (extra vars) or defining them in inventory over hardcoding.

### Docker Compose
-   **Healthchecks:** Mandatory. Used by Ansible to determine if a deployment succeeded.
-   **Restart Policies:** Use `restart: always` or `unless-stopped`.
-   **Versions:** Pin image versions (e.g., `image: n8n:1.2.3`). Avoid `latest` tags in production.

### Shell Scripts
-   Use `set -euo pipefail` for robustness.
-   Include logging functions from `common.sh`.

## 5. Verification Commands

When making changes, verify using the following:

-   **Lint Ansible:** `ansible-lint ansible/playbooks/*.yml` (if installed)
-   **Validate Compose:** `docker compose -f docker/<app>/compose.yaml config`
-   **Test Scripts:** Run `./deploy/trigger-deploy.sh <app>` in a safe environment or with a test app.
