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

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
LOG_DIR="${HOME}/logs/deployments"
LOG_FILE="${LOG_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"
export OPERATION_TYPE="Deployment"

# Source common functions
# shellcheck source=deploy/common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# Functions
# ============================================================================

run_ansible_playbook() {
    local app="$1"

    log "Running Ansible playbook for app: ${app}"

    # Run the deployment playbook in a subshell to avoid cd side effects
    # Capture output to file for error analysis
    # Create temporary file for Ansible output
    output_file=$(mktemp)
    trap 'rm -f -- "$output_file"' EXIT HUP INT QUIT TERM

    local exit_code=0
    (
        cd "${ANSIBLE_DIR}" || exit 1
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
        find "${REPO_DIR}/docker/" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null || echo "  (none found)"
        exit 1
    fi

    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}" 2>/dev/null || true

    log "=========================================="
    log "Starting deployment for app: ${app_name}"
    log "=========================================="

    # Step 1: Validate app name (security check)
    validate_app_name "${app_name}"

    # Step 2: Pull latest code from git
    pull_latest_repo

    # Step 3: Run Ansible playbook
    run_ansible_playbook "${app_name}"

    log "=========================================="
    log "Deployment completed successfully!"
    log "=========================================="
}

main "$@"
