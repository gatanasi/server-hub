# Server Hub

GitOps-driven Infrastructure-as-Code for my self-hosted environment on
Proxmox.

This repository manages Docker-based applications with Ansible, secure
secret handling (SOPS + age), and automated deployments triggered from
GitHub Actions through a restricted SSH entrypoint.

## Highlights

- GitOps deployment flow from repository changes to target VMs
- App-to-host mapping through a single Ansible inventory source of truth
- SOPS-encrypted environment files (`.env.enc`) with runtime decryption on deployer
- Healthcheck-aware deployments with rollback support
- Backup and restore playbooks for Docker named volumes

## Architecture At A Glance

```text
Git push (main)
  |
  v
GitHub Actions / self-hosted runner
  |
  | SSH forced command (restricted)
  v
deployer VM (Ansible + repo checkout + SOPS)
  |
  | SSH
  v
target Docker VMs (one or more apps)
```

For the full pipeline setup and hardening details, see [docs/GITOPS_SETUP.md](docs/GITOPS_SETUP.md).

## Repository Layout

```text
ansible/   Playbooks, tasks, and production inventory
deploy/    Trigger scripts used by GitHub Actions and manual operations
docker/    Per-application Docker Compose definitions
docs/      Operational guides (GitOps, backup/restore, roadmap)
lxc/       LXC container configurations and notes
proxmox/   Provisioning helpers, templates, and host notes
```

## Quick Start

### Prerequisites

- A deployer machine with Ansible, Git, and SOPS installed
- Docker Engine + Docker Compose v2 on each target host
- SSH connectivity from deployer to each target VM
- `age` key material configured for decrypting `.env.enc`

### Install Ansible Collections

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

### Validate A Compose Definition

```bash
docker compose -f docker/n8n/docker-compose.yml config
```

### Trigger A Deployment Manually

```bash
./deploy/trigger.sh deploy n8n
```

The dispatcher also supports backups and restores:

```bash
./deploy/trigger.sh backup n8n --destination /mnt/backups
./deploy/trigger.sh restore n8n list_backups
./deploy/trigger.sh restore n8n restore_latest
```

For detailed setup and workflow examples, see
[docs/GITOPS_SETUP.md](docs/GITOPS_SETUP.md) and
[docs/BACKUP_STRATEGY.md](docs/BACKUP_STRATEGY.md).

## Secrets And Security

- Do not commit plaintext `.env` files.
- Keep application secrets in `.env.enc` (SOPS-encrypted).
- Decryption happens during deployment from the deployer context.

Common SOPS usage:

```bash
# decrypt for inspection
sops --input-type dotenv --output-type dotenv -d docker/<app>/.env.enc

# create encrypted file from plaintext
sops --input-type dotenv --output-type dotenv -e .env > .env.enc
```

## Application Catalog

Source of truth: `managed_apps` in
[ansible/inventory/production.yml](ansible/inventory/production.yml).

To avoid documentation drift, this README does not duplicate app name lists.

- Deployed app mapping:
  [ansible/inventory/production.yml](ansible/inventory/production.yml)
  (`managed_apps`)
- Compose definitions present in repo: [docker/](docker)
- Planned or staged services: [docs/ROADMAP.md](docs/ROADMAP.md)

## Adding A New Application

1. Create `docker/<app-name>/docker-compose.yml`.
2. Add a `healthcheck` block so deployment verification and rollback work
  correctly.
3. Add `docker/<app-name>/.env.enc` if secrets are required.
4. Map the app under a host's `managed_apps` in
  [ansible/inventory/production.yml](ansible/inventory/production.yml).

## Documentation Index

- [docs/GITOPS_SETUP.md](docs/GITOPS_SETUP.md): end-to-end CI/CD and
  secure runner/deployer setup
- [docs/BACKUP_STRATEGY.md](docs/BACKUP_STRATEGY.md): backup and restore
  architecture, workflows, and safety checks
- [docs/ROADMAP.md](docs/ROADMAP.md): planned services and infrastructure decisions
- [lxc/ollama/README.md](lxc/ollama/README.md): notes for Ollama LXC and ROCm tuning

## Roadmap

Future plans are tracked in [docs/ROADMAP.md](docs/ROADMAP.md) to keep
this README focused on the operational baseline.

## Contributing

Issues and pull requests are welcome for improvements to reliability,
security, and operational clarity.

When proposing a new service, include:

- Docker Compose definition (with healthcheck)
- inventory mapping strategy
- backup/restore impact notes

## License

This repository is licensed under the MIT License. See [LICENSE](LICENSE).
