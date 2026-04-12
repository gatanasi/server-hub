#!/usr/bin/env bash
#
# trigger-deploy.sh - Main deployment trigger script
#
# This script is executed on deployer.vm when triggered by the GitHub Actions runner.
# It is called by trigger.sh (the SSH forced command dispatcher) with pre-parsed
# positional arguments — it does NOT parse SSH_ORIGINAL_COMMAND itself.
#
# Usage:
#   ./trigger-deploy.sh <app-name>
#
# Invoked via SSH (handled by trigger.sh):
#   ssh deployer@deployer.vm deploy <app-name>
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
    local app_name="${1:-}"

    # Validate we have an app name
    if [[ -z "${app_name}" ]]; then
        echo "Usage: $0 <app-name>" >&2
        echo "Available apps:" >&2
        { find "${REPO_DIR}/docker/" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | grep . || echo "  (none found)"; } >&2
        exit 1
    fi

    # Reject unexpected extra arguments
    if [[ $# -gt 1 ]]; then
        printf "Error: unexpected extra arguments: %s\n" "${*:2}" >&2
        echo "Usage: $0 <app-name>" >&2
        exit 1
    fi

    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}" 2>/dev/null || true

    log "=========================================="
    log "Starting deployment for app: ${app_name}"
    log "=========================================="

    # Step 1: Pull latest code from git
    pull_latest_repo

    # Step 2: Validate app name (security check)
    validate_app_name "${app_name}"

    # Step 3: Run Ansible playbook
    run_ansible_playbook "${app_name}"

    log "=========================================="
    log "Deployment completed successfully!"
    log "=========================================="
}

main "$@"
