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
OPERATION_TYPE="Deployment"

# Telegram configuration (set these in /home/deployer/.deploy-secrets)
# TELEGRAM_BOT_TOKEN="your-bot-token"
# TELEGRAM_CHAT_ID="your-chat-id"
SECRETS_FILE="/home/deployer/.deploy-secrets"

# Source common functions
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# Functions
# ============================================================================

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
        version=$(grep -E "^\s*image:" "${compose_file}" 2>/dev/null |
            grep -v "x-shared" |
            head -1 |
            sed "s/.*image:\s*//; s/[\"']//g" |
            cut -d@ -f1 |
            xargs 2>/dev/null || echo "")
    fi
    
    echo "${version:-unknown}"
}

run_ansible_playbook() {
    local app="$1"
    
    log "Running Ansible playbook for app: ${app}"
    
    # Run the deployment playbook in a subshell to avoid cd side effects
    # Capture output to file for error analysis
    local output_file
    output_file=$(mktemp)
    
    # Use a robust trap that catches multiple signals and is cleaned up later
    trap "rm -f -- '${output_file}'" EXIT HUP INT QUIT TERM

    local exit_code=0
    (
        cd "${ANSIBLE_DIR}"
        ansible-playbook \
            -i inventory/production.yml \
            playbooks/deploy-docker-app.yml \
            -e "app_name=${app}" \
            -e "repo_dir=${REPO_DIR}" \
            2>&1
    ) | tee -a "${LOG_FILE}" | tee "${output_file}" || exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        # Extract meaningful error details from Ansible output
        local error_details
        error_details=$(extract_ansible_errors "${output_file}" "does not exist" "-B 1 -A 2")
        
        local error_message
        printf -v error_message "Ansible playbook failed with exit code: %s\n\nDetails:\n%s" "${exit_code}" "${error_details}"
        error "${error_message}"
    fi

    # On success, clean up the temp file and disarm the trap
    rm -f -- "${output_file}"
    trap - EXIT HUP INT QUIT TERM
    
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
