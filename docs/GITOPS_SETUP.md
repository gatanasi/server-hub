# GitOps CI/CD Pipeline Setup Guide

## Overview

This document describes how to set up and configure the GitOps deployment pipeline for the server-hub repository. Follow this guide to recreate the infrastructure from scratch.

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

## Part 1: Deployer VM Setup

### Prerequisites

- Ubuntu/Debian VM with user `deployer` that has sudo access
- Network access to GitHub and target VMs
- Git configured with access to the repository

### Step 1.1: Install Dependencies

```bash
# SSH into deployer.vm
ssh deployer@deployer.vm

# Update system
sudo apt-get update

# Install Ansible and dependencies
sudo apt-get install -y ansible git curl

# Install required Ansible collection
ansible-galaxy collection install ansible.posix --force
```

### Step 1.2: Clone Repository

```bash
# Create directory structure
mkdir -p ~/git

# Clone the repository (use your preferred method - HTTPS or SSH)
cd ~/git
git clone git@github.com:gatanasi/server-hub.git

# Or with HTTPS:
# git clone https://github.com/gatanasi/server-hub.git
```

### Step 1.3: Create Required Directories

```bash
# Create log directories
mkdir -p ~/logs/deployments ~/logs/ansible

# Create secrets file (for Telegram notifications - optional)
cat > ~/.deploy-secrets << 'EOF'
# Telegram notifications (optional)
# Get bot token from @BotFather on Telegram
# Get chat ID from @userinfobot on Telegram
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
EOF

chmod 600 ~/.deploy-secrets
```

### Step 1.4: Make Scripts Executable

```bash
chmod +x ~/git/server-hub/deploy/*.sh
```

### Step 1.5: Set Up SSH Keys to Target VMs

For each target VM, ensure deployer.vm can SSH without password:

```bash
# Generate SSH key if not exists
ssh-keygen -t ed25519 -C "deployer@deployer.vm" -f ~/.ssh/id_ed25519 -N ""

# Copy to each target VM
ssh-copy-id -i ~/.ssh/id_ed25519.pub n8n@n8n.vm
# Repeat for other VMs...

# Test connection
ssh n8n@n8n.vm "echo 'SSH OK'"
```

### Step 1.6: Verify Setup

```bash
# Test the trigger script (should show available apps)
~/git/server-hub/deploy/trigger-deploy.sh

# Test Ansible connectivity
cd ~/git/server-hub/ansible
ansible all -m ping
```

---

## Part 2: GitHub Runner SSH Key Setup

This creates the restricted SSH key that allows the runner to trigger deployments.

### Step 2.1: Generate Deployment Key on deployer.vm

```bash
# SSH into deployer.vm
ssh deployer@deployer.vm

# Generate a new keypair specifically for GitHub Actions
ssh-keygen -t ed25519 -C "github-runner-deploy-key" -f ~/.ssh/github_runner_key -N ""

# Display the public key
cat ~/.ssh/github_runner_key.pub
```

### Step 2.2: Configure Forced Command

Add the public key to `authorized_keys` with security restrictions:

```bash
# Get the public key content
PUBKEY=$(cat ~/.ssh/github_runner_key.pub)

# Add with forced command restriction
echo "command=\"/home/deployer/git/server-hub/deploy/trigger-deploy.sh\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ${PUBKEY}" >> ~/.ssh/authorized_keys
```

### Step 2.3: Test the Forced Command

```bash
# This should show the script usage (not a shell)
ssh -i ~/.ssh/github_runner_key deployer@localhost

# This should trigger a deployment
ssh -i ~/.ssh/github_runner_key deployer@localhost n8n
```

### Step 2.4: Get Values for GitHub Secrets

```bash
# Get the PRIVATE key (this goes to GitHub Secrets - NEVER commit this!)
cat ~/.ssh/github_runner_key

# Get the SSH host key for known_hosts
ssh-keyscan -t ed25519 deployer.vm
```

---

## Part 3: GitHub Secrets Configuration

Go to: **Repository → Settings → Secrets and variables → Actions → New repository secret**

### Required Secrets

| Secret Name | How to Get Value |
|-------------|------------------|
| `DEPLOYER_SSH_KEY` | Output of `cat ~/.ssh/github_runner_key` on deployer.vm |
| `DEPLOYER_HOST` | `deployer.vm` (or IP address) |
| `DEPLOYER_USER` | `deployer` |
| `DEPLOYER_SSH_KNOWN_HOSTS` | Output of `ssh-keyscan -t ed25519 deployer.vm` |

### Optional Secrets (Telegram Notifications)

| Secret Name | How to Get Value |
|-------------|------------------|
| `TELEGRAM_BOT_TOKEN` | Create bot with @BotFather, get token |
| `TELEGRAM_CHAT_ID` | Message @userinfobot to get your chat ID |

⚠️ **NEVER commit private keys or tokens to the repository!**

---

## Part 4: GitHub Runner VM Setup

### Prerequisites

- Ubuntu/Debian VM with user `runner`
- Network access to GitHub.com and deployer.vm

### Step 4.1: Install GitHub Actions Runner

Follow GitHub's official guide:

1. Go to Repository → Settings → Actions → Runners → New self-hosted runner
2. Follow the installation commands provided by GitHub

```bash
# Example (get actual commands from GitHub UI)
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.xxx.x.tar.gz -L https://github.com/actions/runner/releases/download/v2.xxx.x/actions-runner-linux-x64-2.xxx.x.tar.gz
tar xzf ./actions-runner-linux-x64-2.xxx.x.tar.gz
./config.sh --url https://github.com/gatanasi/server-hub --token YOUR_TOKEN
./run.sh
```

### Step 4.2: Install as Service (Optional)

```bash
sudo ./svc.sh install
sudo ./svc.sh start
```

### Step 4.3: Install Required Tools

```bash
# Install git and jq (REQUIRED for workflow)
# - git: detects changed files in commits
# - jq: parses JSON for matrix strategy
sudo apt-get update
sudo apt-get install -y git jq

# Verify installations
git --version
jq --version
```

### Step 4.4: Verify Network Connectivity

```bash
# Test that runner can reach deployer.vm
ping -c 3 deployer.vm

# Test SSH (will fail without key, but should connect)
ssh deployer@deployer.vm echo "test" 2>&1 | head -5
```

---

## Part 5: Target VM Setup

For each application VM:

### Step 5.1: Create App User

```bash
# On the target VM
sudo useradd -m -s /bin/bash <app-name>
sudo usermod -aG docker <app-name>
```

### Step 5.2: Create App Directory

```bash
sudo mkdir -p /opt/apps/<app-name>
sudo chown <app-name>:<app-name> /opt/apps/<app-name>
```

### Step 5.3: Create .env File (if needed)

```bash
sudo -u <app-name> nano /opt/apps/<app-name>/.env
```

### Step 5.4: Set Up SSH Access from deployer.vm

On deployer.vm:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub <app-name>@<app-name>.vm
```

### Step 5.5: Update Ansible Inventory

Edit `ansible/inventory/production.yml` to add the new host.

---

## Adding New Applications

### 1. Add to Ansible Inventory

Edit `ansible/inventory/production.yml`:

```yaml
docker_hosts:
  hosts:
    new-app.vm:
      ansible_user: newapp
      ansible_host: new-app.vm
      managed_apps:
        - new-app
```

### 2. Create Docker Compose Directory

```bash
mkdir -p docker/new-app
# Create docker-compose.yml in that directory
```

### 3. Prepare Target VM

Follow Part 5 above for the new VM.

---

## Workflow Triggers

The deployment workflow triggers on:

1. **Push to main**: When any `docker/**/docker-compose.yml` file changes
2. **Manual dispatch**: Actions → Deploy Docker Apps → Run workflow

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

```bash
# On deployer.vm
chmod +x ~/git/server-hub/deploy/*.sh
```

### SSH connection refused from runner

1. Check network connectivity: `ping deployer.vm`
2. Verify GitHub Secrets are correct
3. Check `~/.ssh/authorized_keys` on deployer.vm has the forced command entry

### Container name conflict

```bash
# On target VM, stop existing containers
docker compose -f /path/to/existing/docker-compose.yml down
```

### Missing .env file

```bash
# On target VM
nano /opt/apps/<app>/.env
```

### Ansible "Host unreachable"

```bash
# On deployer.vm, test connectivity
ssh <user>@<target>.vm echo "OK"
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
├── docs/
│   └── GITOPS_SETUP.md             # This file
└── docker/
    ├── n8n/
    │   └── docker-compose.yml
    ├── odoo/
    │   └── docker-compose.yml
    └── ...
```

---

## Security Checklist

- [ ] Private SSH keys are NEVER committed to Git
- [ ] GitHub Secrets are configured (not hardcoded)
- [ ] Forced command is set in authorized_keys
- [ ] SSH key restrictions are applied (no-pty, no-port-forwarding, etc.)
- [ ] Target VM users are in docker group (no sudo needed)
- [ ] .env files with secrets exist only on target VMs (not in Git)
