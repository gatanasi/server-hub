# GitOps CI/CD Pipeline Setup Guide

## Overview

This document describes how to set up and configure the GitOps deployment pipeline for the server-hub repository.

## Architecture

```
GitHub.com (push to main, docker-compose.yml changes)
         │
         ▼
┌─────────────────────┐
│  github-runner.vm   │
│  (self-hosted)      │
│  User: runner       │
└─────────┬───────────┘
          │ SSH with forced command
          │ (can only trigger deploy)
          ▼
┌─────────────────────┐
│  deployer.vm        │
│  User: deployer     │
│  - Ansible          │
│  - SSH keys to VMs  │
└─────────┬───────────┘
          │ Ansible via SSH
          ▼
┌─────────────────────┐
│  Target VMs         │
│  (n8n.vm, etc.)     │
└─────────────────────┘
```

## Security Model

1. **Forced Command SSH**: The GitHub runner's SSH key is restricted with `command="..."` in `authorized_keys` on `deployer.vm`. It can ONLY execute the trigger script - no shell access.

2. **No Production Credentials on Runner**: The runner only has access to trigger deployments. All actual credentials (SSH keys to production VMs) live only on `deployer.vm`.

3. **Restricted Key Options**:
   - `no-port-forwarding`: Prevents SSH port forwarding
   - `no-X11-forwarding`: Prevents X11 forwarding
   - `no-agent-forwarding`: Prevents SSH agent forwarding
   - `no-pty`: Prevents pseudo-terminal allocation

---

## GitHub Secrets Configuration

Go to your repository → Settings → Secrets and variables → Actions → New repository secret

### Required Secrets

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `DEPLOYER_SSH_KEY` | See below | Private SSH key for runner → deployer.vm |
| `DEPLOYER_HOST` | `deployer.vm` | Hostname or IP of deployer VM |
| `DEPLOYER_USER` | `deployer` | Username on deployer VM |
| `DEPLOYER_SSH_KNOWN_HOSTS` | See below | SSH host key entry |

### Optional Secrets (for Telegram notifications)

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `TELEGRAM_BOT_TOKEN` | Your bot token | Get from @BotFather on Telegram |
| `TELEGRAM_CHAT_ID` | Your chat ID | Get from @userinfobot on Telegram |

---

## Secret Values

### DEPLOYER_SSH_KEY

Copy this private key (it's already configured with forced command on deployer.vm):

```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACCedo08M6/p56XHmMf0PGOnyketRCE947jXeNsjlQHPUwAAAKDNdpDozXaQ
6AAAAAtzc2gtZWQyNTUxOQAAACCedo08M6/p56XHmMf0PGOnyketRCE947jXeNsjlQHPUw
AAAEBlAekqRmHlhnSrFoU3EsCq9uUyv5b8hVbCnRkPG7Nna552jTwzr+nnpceYx/Q8Y6fK
R61EIT3juNd42yOVAc9TAAAAGGdpdGh1Yi1ydW5uZXItZGVwbG95LWtleQECAwQF
-----END OPENSSH PRIVATE KEY-----
```

### DEPLOYER_HOST

```
deployer.vm
```

### DEPLOYER_USER

```
deployer
```

### DEPLOYER_SSH_KNOWN_HOSTS

```
deployer.vm ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYblFhrwZkmt8pY3c+B4HgZZ7l8m6xFaRFNG4By/yAy
```

---

## Adding New Target VMs

To add a new application/VM to the deployment pipeline:

### 1. Ensure SSH access from deployer.vm

```bash
# On deployer.vm, test SSH to new VM
ssh <user>@<new-vm> echo "Connection OK"
```

### 2. Update Ansible inventory

Edit `ansible/inventory/production.yml`:

```yaml
docker_hosts:
  hosts:
    # Existing hosts...
    
    new-app.vm:
      ansible_user: newapp
      ansible_host: new-app.vm
      managed_apps:
        - new-app
```

### 3. Create the docker-compose directory

```
docker/
└── new-app/
    └── docker-compose.yml
```

### 4. Create app directory on target VM

```bash
ssh <user>@<new-vm> "mkdir -p /opt/apps/new-app"
```

### 5. Create .env file on target VM (if needed)

```bash
ssh <user>@<new-vm> "nano /opt/apps/new-app/.env"
```

---

## Workflow Triggers

The deployment workflow triggers on:

1. **Push to main**: When any `docker/**/docker-compose.yml` file changes
2. **Manual dispatch**: Run workflow manually with app name input

---

## Manual Deployment

### From deployer.vm

```bash
~/git/server-hub/deploy/trigger-deploy.sh <app-name>
```

### From GitHub Actions

Go to Actions → Deploy Docker Apps → Run workflow → Enter app name

---

## Troubleshooting

### Deployment fails with "Permission denied"

Ensure scripts are executable:
```bash
chmod +x ~/git/server-hub/deploy/*.sh
```

### SSH connection refused

Check that the runner can reach deployer.vm:
```bash
ssh -i ~/.ssh/deploy_key deployer@deployer.vm
```

### Container name conflict

If containers already exist with the same names, stop them first:
```bash
docker compose -f /path/to/existing/docker-compose.yml down
```

### Missing .env file

Create the .env file on the target VM:
```bash
ssh <user>@<target-vm> "nano /opt/apps/<app>/.env"
```

---

## File Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml              # GitHub Actions workflow
├── ansible/
│   ├── ansible.cfg                 # Ansible configuration  
│   ├── inventory/
│   │   └── production.yml          # Target VMs inventory
│   └── playbooks/
│       └── deploy-docker-app.yml   # Deployment playbook
├── deploy/
│   ├── trigger-deploy.sh           # Main trigger script (forced command)
│   └── setup-deployer-vm.sh        # One-time setup script
└── docker/
    ├── n8n/
    │   └── docker-compose.yml
    ├── odoo/
    │   └── docker-compose.yml
    └── ...
```
