#!/usr/bin/env bash
#
# setup-deployer-vm.sh - Set up the deployer VM for GitOps deployments
#
# This script should be run ON the deployer.vm as the 'deployer' user.
# It sets up:
#   1. Required directories and permissions
#   2. Ansible installation (if not present)
#   3. Log directories
#   4. SSH configuration
#
# Usage:
#   ./setup-deployer-vm.sh
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

DEPLOYER_USER="${USER:-deployer}"
DEPLOYER_HOME="${HOME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="/var/log/deployments"
ANSIBLE_LOG_DIR="/var/log/ansible"

# ============================================================================
# Functions
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

check_user() {
    if [[ "${USER}" != "deployer" ]]; then
        log "WARNING: Running as ${USER}, expected 'deployer'"
        log "Some operations may fail or need adjustment"
    fi
}

setup_directories() {
    log "Setting up directories..."
    
    # Create log directories (needs sudo)
    if [[ ! -d "${LOG_DIR}" ]]; then
        log "Creating ${LOG_DIR} (requires sudo)..."
        sudo mkdir -p "${LOG_DIR}"
        sudo chown "${DEPLOYER_USER}:${DEPLOYER_USER}" "${LOG_DIR}"
        sudo chmod 755 "${LOG_DIR}"
    fi
    
    if [[ ! -d "${ANSIBLE_LOG_DIR}" ]]; then
        log "Creating ${ANSIBLE_LOG_DIR} (requires sudo)..."
        sudo mkdir -p "${ANSIBLE_LOG_DIR}"
        sudo chown "${DEPLOYER_USER}:${DEPLOYER_USER}" "${ANSIBLE_LOG_DIR}"
        sudo chmod 755 "${ANSIBLE_LOG_DIR}"
    fi
    
    log "Directories configured"
}

install_ansible() {
    log "Checking Ansible installation..."
    
    if command -v ansible &> /dev/null; then
        log "Ansible is already installed: $(ansible --version | head -1)"
        return 0
    fi
    
    log "Installing Ansible..."
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y ansible rsync
    elif command -v dnf &> /dev/null; then
        # Fedora/RHEL
        sudo dnf install -y ansible rsync
    elif command -v yum &> /dev/null; then
        # Older RHEL/CentOS
        sudo yum install -y ansible rsync
    elif command -v pacman &> /dev/null; then
        # Arch
        sudo pacman -Sy ansible rsync --noconfirm
    elif command -v apk &> /dev/null; then
        # Alpine
        sudo apk add ansible rsync
    else
        log "ERROR: Unknown package manager. Please install Ansible manually."
        log "See: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html"
        exit 1
    fi
    
    log "Ansible installed: $(ansible --version | head -1)"
}

install_ansible_collections() {
    log "Installing required Ansible collections..."
    
    # Install the posix collection (needed for synchronize module)
    ansible-galaxy collection install ansible.posix --force
    
    log "Ansible collections installed"
}

setup_git_repo() {
    log "Checking git repository..."
    
    if [[ ! -d "${REPO_DIR}" ]]; then
        log "WARNING: Git repository not found at ${REPO_DIR}"
        log "Please clone the repository:"
        log "  git clone git@github.com:YOUR_ORG/server-hub.git ${REPO_DIR}"
        return 1
    fi
    
    if [[ ! -d "${REPO_DIR}/.git" ]]; then
        log "ERROR: ${REPO_DIR} is not a git repository"
        return 1
    fi
    
    # Make trigger script executable
    if [[ -f "${REPO_DIR}/deploy/trigger-deploy.sh" ]]; then
        chmod +x "${REPO_DIR}/deploy/trigger-deploy.sh"
        log "Made trigger-deploy.sh executable"
    else
        log "WARNING: trigger-deploy.sh not found. Run 'git pull' to get latest files."
    fi
    
    log "Git repository OK"
}

setup_secrets_file() {
    local secrets_file="${DEPLOYER_HOME}/.deploy-secrets"
    
    if [[ -f "${secrets_file}" ]]; then
        log "Secrets file already exists: ${secrets_file}"
        return 0
    fi
    
    log "Creating secrets file template..."
    
    cat > "${secrets_file}" <<'EOF'
# Deployment secrets - DO NOT COMMIT THIS FILE
# This file is sourced by trigger-deploy.sh for notifications

# Telegram notifications (optional)
# Get these from @BotFather on Telegram
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
EOF
    
    chmod 600 "${secrets_file}"
    
    log "Created ${secrets_file}"
    log "Edit this file to add your Telegram credentials for notifications"
}

check_ssh_keys() {
    log "Checking SSH configuration..."
    
    local ssh_dir="${DEPLOYER_HOME}/.ssh"
    
    if [[ ! -d "${ssh_dir}" ]]; then
        mkdir -p "${ssh_dir}"
        chmod 700 "${ssh_dir}"
    fi
    
    if [[ ! -f "${ssh_dir}/id_ed25519" && ! -f "${ssh_dir}/id_rsa" ]]; then
        log "WARNING: No SSH key found for deployer user"
        log "You may need to create one to connect to target VMs:"
        log "  ssh-keygen -t ed25519 -C 'deployer@deployer.vm'"
    else
        log "SSH key exists"
    fi
    
    log "SSH configuration OK"
}

print_next_steps() {
    echo ""
    echo "=========================================="
    echo "Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Update git repository (if not done):"
    echo "   cd ${REPO_DIR} && git pull"
    echo ""
    echo "2. Configure Telegram notifications (optional):"
    echo "   nano ${DEPLOYER_HOME}/.deploy-secrets"
    echo ""
    echo "3. Test the trigger script:"
    echo "   ${REPO_DIR}/deploy/trigger-deploy.sh n8n"
    echo ""
    echo "4. Test Ansible connectivity to target VMs:"
    echo "   cd ${REPO_DIR}/ansible"
    echo "   ansible all -m ping"
    echo ""
    echo "5. Set up SSH key for GitHub Actions runner"
    echo "   (See Phase 2 in the setup guide)"
    echo ""
    echo "=========================================="
}

# ============================================================================
# Main
# ============================================================================

main() {
    log "=========================================="
    log "Deployer VM Setup Script"
    log "=========================================="
    
    check_user
    setup_directories
    install_ansible
    install_ansible_collections
    setup_git_repo
    setup_secrets_file
    check_ssh_keys
    
    print_next_steps
}

main "$@"
