#!/usr/bin/env bash
#
# trigger-backup.sh - Backup Docker volumes for an application
#
# This script is called by trigger.sh when the 'backup' operation is requested.
#
# Usage:
#   ./trigger-backup.sh <app-name> [options]
#
# Options:
#   --destination <path>    Backup destination (default: /mnt/backups)
#   --host <hostname>       Target specific host
#
# Examples:
#   ./trigger-backup.sh n8n
#   ./trigger-backup.sh odoo --destination /mnt/backups
#   ./trigger-backup.sh all --host n8n.vm
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

REPO_DIR="/home/deployer/git/server-hub"
ANSIBLE_DIR="${REPO_DIR}/ansible"
LOG_DIR="/home/deployer/logs/backups"
LOG_FILE="${LOG_DIR}/backup-$(date +%Y%m%d-%H%M%S).log"
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
    local msg="$*"
    log "ERROR: ${msg}"
    send_notification "❌ Backup FAILED" "${msg}"
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
    echo "Usage: $0 <app-name> [options]"
    echo ""
    echo "Backup Docker volumes for an application."
    echo ""
    echo "Arguments:"
    echo "  <app-name>              Application to backup (or 'all' for all apps)"
    echo ""
    echo "Options:"
    echo "  --destination <path>    Backup destination (default: /mnt/backups)"
    echo "  --host <hostname>       Target specific host"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 n8n"
    echo "  $0 odoo --destination /mnt/backups"
    echo "  $0 all --host n8n.vm"
}

validate_app_name() {
    local app="$1"
    
    # Security: Only allow alphanumeric, dash, and underscore
    if [[ ! "${app}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Invalid app name: ${app}. Only alphanumeric, dash, and underscore allowed."
    fi
    
    # 'all' is a valid app name for backup
    if [[ "${app}" == "all" ]]; then
        return 0
    fi
    
    # Check if docker-compose.yml exists for this app
    if [[ ! -f "${REPO_DIR}/docker/${app}/docker-compose.yml" ]]; then
        error "No docker-compose.yml found for app: ${app}"
    fi
}

pull_latest_repo() {
    log "Pulling latest changes from git..."
    
    (
        cd "${REPO_DIR}"
        git fetch origin main
        git reset --hard origin/main
        chmod +x "${REPO_DIR}/deploy/"*.sh 2>/dev/null || true
    )
    
    log "Git pull complete. Current commit: $(cd "${REPO_DIR}" && git rev-parse --short HEAD)"
}

run_backup_playbook() {
    local app="$1"
    local backup_dest="$2"
    local target_host="$3"
    
    log "Running backup playbook for app: ${app}"
    
    # Build ansible command arguments
    local ansible_args=("-i" "inventory/production.yml" "playbooks/backup-docker-volumes.yml")
    ansible_args+=("-e" "backup_destination=${backup_dest}")
    
    if [[ "${app}" != "all" ]]; then
        ansible_args+=("-e" "app_name=${app}")
    fi
    
    if [[ -n "${target_host}" ]]; then
        ansible_args+=("-l" "${target_host}")
    fi
    
    # Run the backup playbook in a subshell to avoid cd side effects
    # Note: We use || exit_code=$? to prevent set -e from killing the script before we can send notifications
    local exit_code=0
    (
        cd "${ANSIBLE_DIR}"
        ansible-playbook "${ansible_args[@]}" 2>&1
    ) | tee -a "${LOG_FILE}" || exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        error "Backup playbook failed with exit code: ${exit_code}"
    fi
    
    log "Backup playbook completed successfully"
}

# ============================================================================
# Main
# ============================================================================

main() {
    local app_name=""
    local backup_dest="/mnt/backups"
    local target_host=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --destination)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    echo "Error: --destination requires a path argument"
                    show_help
                    exit 1
                fi
                backup_dest="$2"
                shift 2
                ;;
            --host)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    echo "Error: --host requires a hostname argument"
                    show_help
                    exit 1
                fi
                target_host="$2"
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
                fi
                shift
                ;;
        esac
    done
    
    # Validate app name is provided
    if [[ -z "${app_name}" ]]; then
        echo "Error: App name is required"
        show_help
        exit 1
    fi
    
    # Create log directory
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    log "=========================================="
    log "Starting backup for app: ${app_name}"
    log "=========================================="
    
    # Validate inputs
    validate_app_name "${app_name}"
    
    # Validate backup destination (security check)
    if [[ ! "${backup_dest}" =~ ^/[a-zA-Z0-9/_.-]+$ ]]; then
        error "Invalid backup destination: ${backup_dest}. Must be an absolute path without special characters."
    fi
    # Check for path traversal: reject if contains '/..' or '../' anywhere
    if [[ "${backup_dest}" == *".."* ]]; then
        error "Backup destination cannot contain path traversal components ('..')"
    fi
    
    # Validate target host if provided
    if [[ -n "${target_host}" && ! "${target_host}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Invalid target host: ${target_host}"
    fi
    
    # Pull latest code
    pull_latest_repo
    
    # Run backup
    run_backup_playbook "${app_name}" "${backup_dest}" "${target_host}"
    
    # Send success notification
    local target_info=""
    if [[ -n "${target_host}" ]]; then
        target_info="%0AHost: <code>${target_host}</code>"
    fi
    send_notification "💾 Backup SUCCESS" "App: <code>${app_name}</code>${target_info}%0ADestination: <code>${backup_dest}</code>"
    
    log "=========================================="
    log "Backup completed successfully!"
    log "=========================================="
}

main "$@"
