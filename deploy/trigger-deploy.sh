#!/usr/bin/env bash
#
# trigger-deploy.sh - Main deployment trigger script
#
# This script is executed on deployer.vm when triggered by the GitHub Actions runner.
# It is called via SSH forced command, so arguments come from SSH_ORIGINAL_COMMAND.
#
# Usage (when called directly for testing):
#   ./trigger-deploy.sh <app-name>
#
# Usage (when called via forced SSH command):
#   ssh deployer@deployer.vm <app-name>
#
# Example:
#   ./trigger-deploy.sh n8n
#   ssh deployer@deployer.vm n8n
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="/home/deployer/git/server-hub"
ANSIBLE_DIR="${REPO_DIR}/ansible"
LOG_DIR="/home/deployer/logs/deployments"
LOG_FILE="${LOG_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"

# Telegram configuration (set these in /home/deployer/.deploy-secrets)
# TELEGRAM_BOT_TOKEN="your-bot-token"
# TELEGRAM_CHAT_ID="your-chat-id"
SECRETS_FILE="/home/deployer/.deploy-secrets"

# ============================================================================
# Functions
# ============================================================================

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $*" | tee -a "${LOG_FILE}"
}

error() {
    log "ERROR: $*"
    send_notification "❌ Deployment FAILED" "$*"
    exit 1
}

send_notification() {
    local title="$1"
    local message="$2"
    
    if [[ -f "${SECRETS_FILE}" ]]; then
        # shellcheck source=/dev/null
        source "${SECRETS_FILE}"
    fi
    
    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        local text="${title}%0A%0A${message}"
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${text}" \
            -d "parse_mode=HTML" > /dev/null 2>&1 || true
    fi
}

validate_app_name() {
    local app="$1"
    
    # Security: Only allow alphanumeric, dash, and underscore
    if [[ ! "${app}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Invalid app name: ${app}. Only alphanumeric, dash, and underscore allowed."
    fi
    
    # Check if docker-compose.yml exists for this app
    if [[ ! -f "${REPO_DIR}/docker/${app}/docker-compose.yml" ]]; then
        error "No docker-compose.yml found for app: ${app}"
    fi
}

# Extract version from a docker-compose.yml file
# Looks for the main service image and extracts the tag
extract_version() {
    local compose_file="$1"
    local version=""
    
    if [[ -f "${compose_file}" ]]; then
        # Extract image tag, handling various formats:
        # - image: nginx:1.25
        # - image: "docker.io/n8nio/n8n:2.1.4"
        # - image: postgres:16.11@sha256:...
        version=$(grep -E "^\s*image:" "${compose_file}" 2>/dev/null | \
            grep -v "x-shared" | \
            head -1 | \
            sed "s/.*image:\s*//; s/[\"']//g" | \
            cut -d@ -f1 | \
            xargs 2>/dev/null || echo "")
    fi
    
    echo "${version:-unknown}"
}

pull_latest_repo() {
    log "Pulling latest changes from git..."
    cd "${REPO_DIR}"
    
    # Fetch and reset to origin/main to ensure clean state
    git fetch origin main
    git reset --hard origin/main
    
    # Ensure deploy scripts are executable (git doesn't preserve permissions)
    chmod +x "${REPO_DIR}/deploy/"*.sh 2>/dev/null || true
    
    log "Git pull complete. Current commit: $(git rev-parse --short HEAD)"
}

run_ansible_playbook() {
    local app="$1"
    
    log "Running Ansible playbook for app: ${app}"
    
    cd "${ANSIBLE_DIR}"
    
    # Run the deployment playbook
    ansible-playbook \
        -i inventory/production.yml \
        playbooks/deploy-docker-app.yml \
        -e "app_name=${app}" \
        -e "repo_dir=${REPO_DIR}" \
        2>&1 | tee -a "${LOG_FILE}"
    
    local exit_code=${PIPESTATUS[0]}
    
    if [[ ${exit_code} -ne 0 ]]; then
        error "Ansible playbook failed with exit code: ${exit_code}"
    fi
    
    log "Ansible playbook completed successfully"
}

# ============================================================================
# Main
# ============================================================================

main() {
    local app_name=""
    
    # Handle arguments: either direct args or SSH_ORIGINAL_COMMAND
    if [[ -n "${SSH_ORIGINAL_COMMAND:-}" ]]; then
        # Called via forced SSH command
        # shellcheck disable=SC2086
        set -- ${SSH_ORIGINAL_COMMAND}
        app_name="${1:-}"
    else
        # Called directly (for testing)
        app_name="${1:-}"
    fi
    
    # Validate we have an app name
    if [[ -z "${app_name}" ]]; then
        echo "Usage: $0 <app-name>"
        echo "Available apps:"
        ls -1 "${REPO_DIR}/docker/" 2>/dev/null | grep -v '^$' || echo "  (none found)"
        exit 1
    fi
    
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    log "=========================================="
    log "Starting deployment for app: ${app_name}"
    log "=========================================="
    
    # Step 1: Validate app name (security check)
    validate_app_name "${app_name}"
    
    # Step 2: Capture current version before pulling new code
    local compose_file="${REPO_DIR}/docker/${app_name}/docker-compose.yml"
    local old_version
    old_version=$(extract_version "${compose_file}")
    
    # Step 3: Pull latest code from git
    pull_latest_repo
    
    # Step 4: Get new version after pull
    local new_version
    new_version=$(extract_version "${compose_file}")
    
    # Step 5: Run Ansible playbook
    run_ansible_playbook "${app_name}"
    
    # Step 6: Send success notification with version info
    local version_info
    if [[ "${old_version}" != "${new_version}" && "${old_version}" != "unknown" ]]; then
        version_info="Version: <code>${old_version}</code> → <code>${new_version}</code>"
    else
        version_info="Version: <code>${new_version}</code>"
    fi
    
    send_notification "✅ Deployment SUCCESS" "App: <code>${app_name}</code>%0A${version_info}"
    
    log "=========================================="
    log "Deployment completed successfully!"
    log "=========================================="
}

main "$@"
