#!/usr/bin/env bash
#
# common.sh - Shared functions for deploy scripts
#
# This script provides common functions used by trigger-backup.sh and trigger-restore.sh
# It should be sourced, not executed directly.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
#

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# ============================================================================
# Configuration (can be overridden before sourcing)
# ============================================================================

# Calculate directories relative to this script
# Use a distinct variable name to avoid conflict with the sourcing script
COMMON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="${REPO_DIR:-$(cd "${COMMON_SCRIPT_DIR}/.." && pwd)}"
ANSIBLE_DIR="${ANSIBLE_DIR:-${REPO_DIR}/ansible}"

SECRETS_FILE="${SECRETS_FILE:-${HOME}/.deploy-secrets}"

# These must be set by the sourcing script
: "${LOG_FILE:?LOG_FILE must be set before sourcing common.sh}"
: "${OPERATION_TYPE:?OPERATION_TYPE must be set before sourcing common.sh (e.g., 'Backup' or 'Restore')}"

# ============================================================================
# Logging Functions
# ============================================================================

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $*" | tee -a "${LOG_FILE}"
}

error() {
    local msg="$*"
    log "ERROR: ${msg}"
    exit 1
}

# ============================================================================
# Ansible Configuration
# ============================================================================

# Enable file-based logging for Ansible in production
export ANSIBLE_LOG_PATH="${HOME}/logs/ansible/ansible.log"
mkdir -p "$(dirname "${ANSIBLE_LOG_PATH}")"

# ============================================================================
# Validation Functions
# ============================================================================

validate_app_name() {
    local app="$1"
    local allow_all="${2:-false}"
    
    # Security: Only allow alphanumeric, dash, and underscore
    if [[ ! "${app}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Invalid app name: ${app}. Only alphanumeric, dash, and underscore allowed."
    fi
    
    # 'all' is a valid app name only for backup operations
    if [[ "${app}" == "all" ]]; then
        if [[ "${allow_all}" == "true" ]]; then
            return 0
        else
            error "App name 'all' is not allowed for this operation."
        fi
    fi
    
    # Check if docker-compose.yml exists for this app
    if [[ ! -f "${REPO_DIR}/docker/${app}/docker-compose.yml" ]]; then
        error "No docker-compose.yml found for app: ${app}"
    fi
}

validate_path() {
    local path="$1"
    local path_name="$2"
    
    # Must be an absolute path without special characters
    if [[ ! "${path}" =~ ^/[a-zA-Z0-9/_.-]+$ ]]; then
        error "Invalid ${path_name}: ${path}. Must be an absolute path without special characters."
    fi
    
    # Check for path traversal
    if [[ "${path}" == *".."* ]]; then
        error "${path_name} cannot contain path traversal components ('..')"
    fi
}

validate_hostname() {
    local host="$1"
    
    if [[ -n "${host}" && ! "${host}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Invalid target host: ${host}"
    fi
}

# ============================================================================
# Error Extraction Functions
# ============================================================================

# Extract error details from Ansible output file for notifications
# Usage: extract_ansible_errors <output_file> [additional_pattern] [context_lines]
#   output_file: Path to the file containing Ansible output
#   additional_pattern: Optional grep -E pattern to search for (e.g., "does not exist")
#   context_lines: Optional context lines for additional pattern (e.g., "-B 1 -A 2")
# Returns: Error details string (truncated to 500 chars)
extract_ansible_errors() {
    local output_file="$1"
    local additional_pattern="${2:-}"
    local context_lines="${3:-}"
    local error_details=""
    
    # Look for failed tasks (always check this)
    local failed_tasks
    failed_tasks=$(grep -E "^fatal:|FAILED!" "${output_file}" | head -5 || true)
    if [[ -n "${failed_tasks}" ]]; then
        error_details="${failed_tasks}"
    fi
    
    # Look for additional pattern if provided
    if [[ -n "${additional_pattern}" ]]; then
        if grep -qE "${additional_pattern}" "${output_file}"; then
            local matched
            if [[ -n "${context_lines}" ]]; then
                # Use context lines (e.g., -B 1 -A 2)
                # shellcheck disable=SC2086
                matched=$(grep ${context_lines} -E "${additional_pattern}" "${output_file}" | head -5 || true)
            else
                matched=$(grep -E "${additional_pattern}" "${output_file}" | head -3 || true)
            fi
            if [[ -n "${matched}" ]]; then
                if [[ -n "${error_details}" ]]; then
                    error_details+=$'\n'"${matched}"
                else
                    error_details="${matched}"
                fi
            fi
        fi
    fi
    
    # Truncate for notification (Telegram has message limits)
    if [[ ${#error_details} -gt 500 ]]; then
        error_details="${error_details:0:500}..."
    fi
    
    echo "${error_details}"
}

# ============================================================================
# Git Functions
# ============================================================================

pull_latest_repo() {
    log "Pulling latest changes from git..."
    
    (
        cd "${REPO_DIR}" || exit 1
        # Get current branch name
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        
        git fetch origin "${current_branch}"
        git reset --hard "origin/${current_branch}"
        chmod +x "${REPO_DIR}/deploy/"*.sh 2>/dev/null || true
    )
    
    log "Git pull complete. Current commit: $(cd "${REPO_DIR}" && git rev-parse --short HEAD)"
}
