#!/usr/bin/env bash
#
# trigger-restore.sh - Restore Docker volumes for an application
#
# This script is called by trigger.sh when the 'restore' operation is requested.
#
# Usage:
#   ./trigger-restore.sh <app-name> <operation> [options]
#
# Operations:
#   list_backups       List available backups
#   restore_latest     Restore from the latest backup
#   restore_specific   Restore from a specific backup (requires --timestamp)
#
# Options:
#   --source <path>           Backup source path (default: /mnt/backups)
#   --timestamp <TIMESTAMP>   Backup timestamp for restore_specific (format: YYYYMMDDTHHMMSS)
#
# Examples:
#   ./trigger-restore.sh n8n list_backups
#   ./trigger-restore.sh n8n restore_latest
#   ./trigger-restore.sh n8n restore_specific --timestamp 20260106T143000
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

REPO_DIR="/home/deployer/git/server-hub"
ANSIBLE_DIR="${REPO_DIR}/ansible"
LOG_DIR="/home/deployer/logs/restores"
LOG_FILE="${LOG_DIR}/restore-$(date +%Y%m%d-%H%M%S).log"
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
    send_notification "❌ Restore FAILED" "$*"
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

show_help() {
    echo "Usage: $0 <app-name> <operation> [options]"
    echo ""
    echo "Restore Docker volumes for an application."
    echo ""
    echo "Arguments:"
    echo "  <app-name>              Application to restore"
    echo "  <operation>             One of: list_backups, restore_latest, restore_specific"
    echo ""
    echo "Options:"
    echo "  --source <path>         Backup source path (default: /mnt/backups)"
    echo "  --timestamp <TS>        Backup timestamp for restore_specific (YYYYMMDDTHHMMSS)"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 n8n list_backups"
    echo "  $0 n8n restore_latest"
    echo "  $0 n8n restore_specific --timestamp 20260106T143000"
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

pull_latest_repo() {
    log "Pulling latest changes from git..."
    cd "${REPO_DIR}"
    
    git fetch origin main
    git reset --hard origin/main
    
    chmod +x "${REPO_DIR}/deploy/"*.sh 2>/dev/null || true
    
    log "Git pull complete. Current commit: $(git rev-parse --short HEAD)"
}

run_restore_playbook() {
    local app="$1"
    local restore_op="$2"
    local backup_src="$3"
    local timestamp="$4"
    
    log "Running restore playbook for app: ${app}, operation: ${restore_op}"
    
    cd "${ANSIBLE_DIR}"
    
    # Build ansible command arguments
    local ansible_args=("-i" "inventory/production.yml" "playbooks/restore-docker-volumes.yml")
    ansible_args+=("-e" "app_name=${app}")
    ansible_args+=("-e" "backup_source=${backup_src}")
    
    case "${restore_op}" in
        list_backups)
            ansible_args+=("-e" "list_only=true")
            ;;
        restore_latest)
            ansible_args+=("-e" "auto_confirm=true")
            ;;
        restore_specific)
            ansible_args+=("-e" "auto_confirm=true")
            ansible_args+=("-e" "backup_timestamp=${timestamp}")
            ;;
        *)
            error "Unknown restore operation: ${restore_op}"
            ;;
    esac
    
    # Run the restore playbook
    ansible-playbook "${ansible_args[@]}" 2>&1 | tee -a "${LOG_FILE}"
    
    local exit_code=${PIPESTATUS[0]}
    
    if [[ ${exit_code} -ne 0 ]]; then
        error "Restore playbook failed with exit code: ${exit_code}"
    fi
    
    log "Restore playbook completed successfully"
}

# ============================================================================
# Main
# ============================================================================

main() {
    local app_name=""
    local restore_op=""
    local backup_src="/mnt/backups"
    local timestamp=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --source)
                backup_src="${2:-/mnt/backups}"
                shift 2
                ;;
            --timestamp)
                timestamp="${2:-}"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "${app_name}" ]]; then
                    app_name="$1"
                elif [[ -z "${restore_op}" ]]; then
                    restore_op="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "${app_name}" ]]; then
        echo "Error: App name is required"
        show_help
        exit 1
    fi
    
    if [[ -z "${restore_op}" ]]; then
        echo "Error: Operation is required"
        show_help
        exit 1
    fi
    
    # Create log directory
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    log "=========================================="
    log "Starting restore for app: ${app_name}"
    log "Operation: ${restore_op}"
    log "=========================================="
    
    # Validate inputs
    validate_app_name "${app_name}"
    
    # Validate restore operation
    if [[ ! "${restore_op}" =~ ^(list_backups|restore_latest|restore_specific)$ ]]; then
        error "Invalid restore operation: ${restore_op}. Must be list_backups, restore_latest, or restore_specific."
    fi
    
    # Validate backup source (security check)
    if [[ ! "${backup_src}" =~ ^/[a-zA-Z0-9/_.-]+$ ]]; then
        error "Invalid backup source: ${backup_src}. Must be an absolute path without special characters."
    fi
    if [[ "${backup_src}" =~ (^|/)\.\./|/\.\.$|(^|/)\.\. ]]; then
        error "Backup source cannot contain path traversal components ('..')"
    fi
    
    # Validate timestamp if restore_specific
    if [[ "${restore_op}" == "restore_specific" ]]; then
        if [[ -z "${timestamp}" ]]; then
            error "Timestamp is required for restore_specific operation. Use --timestamp YYYYMMDDTHHMMSS"
        fi
        if [[ ! "${timestamp}" =~ ^[0-9]{8}T[0-9]{6}$ ]]; then
            error "Invalid timestamp format: ${timestamp}. Expected: YYYYMMDDTHHMMSS (e.g., 20260106T143000)"
        fi
    fi
    
    # Pull latest code
    pull_latest_repo
    
    # Run restore
    run_restore_playbook "${app_name}" "${restore_op}" "${backup_src}" "${timestamp}"
    
    # Send success notification (skip for list_backups)
    if [[ "${restore_op}" != "list_backups" ]]; then
        local restore_info=""
        if [[ "${restore_op}" == "restore_latest" ]]; then
            restore_info="latest backup"
        else
            restore_info="backup ${timestamp}"
        fi
        send_notification "🔄 Restore SUCCESS" "App: <code>${app_name}</code>%0ARestored: ${restore_info}"
    fi
    
    log "=========================================="
    log "Restore completed successfully!"
    log "=========================================="
}

main "$@"
