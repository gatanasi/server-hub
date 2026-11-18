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

# Log the error and exit. on_exit sends the failure alert with this message as the reason.
error() {
    local msg="$*"
    log "ERROR: ${msg}"
    FAILURE_REASON="${msg}"
    exit 1
}

# ============================================================================
# Notification Functions
# ============================================================================

# Escape the characters Telegram's HTML parse mode reads as markup.
html_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# Send a Telegram message with the credentials in SECRETS_FILE.
# Best effort: a missing file, empty credentials or an API error never fail the caller.
# The subshell keeps the sourced secrets out of the caller's variables.
send_telegram() {
    local text="$1"
    (
        [[ -f "${SECRETS_FILE}" ]] || exit 0
        # shellcheck disable=SC1090
        source "${SECRETS_FILE}"
        [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]] || exit 0
        # The URL goes through a curl config on stdin so the bot token stays out of the process list.
        printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "${TELEGRAM_BOT_TOKEN}" |
            curl --config - --silent --show-error --fail --max-time 10 --output /dev/null \
                --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
                --data-urlencode "parse_mode=HTML" \
                --data-urlencode "text=${text}"
    ) || log "WARNING: Could not send the Telegram failure notification"
}

# Report a failed run. Set NOTIFY_APP in the calling script to name the app in the message.
notify_failure() {
    local details="$1"
    local text="❌ <b>${OPERATION_TYPE} Failed</b>"$'\n\n'
    if [[ -n "${NOTIFY_APP:-}" ]]; then
        text+="App: <code>$(html_escape "${NOTIFY_APP}")</code>"$'\n'
    fi
    text+="<pre>$(html_escape "${details}")</pre>"
    send_telegram "${text}"
}

# ============================================================================
# Exit Handling
# ============================================================================

# Every script that sources this file leaves through on_exit, whatever ends it: error(),
# a command failing under set -e, or a signal. It is the one place that removes temp files
# and sends the failure alert, so no failure skips the alert and none sends two.
# Scripts must not set their own EXIT trap; they register temp files instead.
TEMP_FILES=()
FAILURE_REASON=""

register_temp_file() {
    TEMP_FILES+=("$1")
}

on_exit() {
    local rc=$?
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        rm -f -- "${TEMP_FILES[@]}"
    fi
    if [[ ${rc} -ne 0 ]]; then
        notify_failure "${FAILURE_REASON:-Exited with status ${rc} before finishing. Log on deployer: ${LOG_FILE}}"
    fi
}

trap on_exit EXIT
# Leave through on_exit on these signals too (exit status 128 + signal number).
trap 'FAILURE_REASON="Interrupted by SIGHUP (connection to the runner lost?)"; exit 129' HUP
trap 'FAILURE_REASON="Interrupted by SIGINT"; exit 130' INT
trap 'FAILURE_REASON="Interrupted by SIGQUIT"; exit 131' QUIT
trap 'FAILURE_REASON="Interrupted by SIGTERM"; exit 143' TERM

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
    
    # Check if compose.yaml exists for this app
    if [[ ! -f "${REPO_DIR}/docker/${app}/compose.yaml" ]]; then
        error "No compose.yaml found for app: ${app}"
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

    # No subshell: error() has to run in the main shell for on_exit to see its reason.
    local current_branch
    current_branch=$(git -C "${REPO_DIR}" symbolic-ref --short HEAD 2>/dev/null) ||
        error "Cannot deploy from a detached HEAD state. Please check out a branch."
    git -C "${REPO_DIR}" fetch origin "${current_branch}" ||
        error "git fetch of '${current_branch}' from origin failed. Check GitHub access from deployer."
    git -C "${REPO_DIR}" reset --hard "origin/${current_branch}" ||
        error "git reset to origin/${current_branch} failed."

    log "Git pull complete. Current commit: $(git -C "${REPO_DIR}" rev-parse --short HEAD)"
}
