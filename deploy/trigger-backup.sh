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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
export OPERATION_TYPE="Backup"

LOG_DIR="${HOME}/logs/backups"
LOG_FILE="${LOG_DIR}/backup-$(date +%Y%m%d-%H%M%S).log"
export OPERATION_TYPE="Backup"

# shellcheck source=deploy/common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# Functions
# ============================================================================

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
    # Capture output to file for error analysis
    # Create temporary file for Ansible output
    output_file=$(mktemp)
    trap 'rm -f -- "$output_file"' EXIT HUP INT QUIT TERM

    local exit_code=0
    (
        cd "${ANSIBLE_DIR}"
        ansible-playbook "${ansible_args[@]}" 2>&1
    ) | tee -a "${LOG_FILE}" | tee "${output_file}" || exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        # Extract meaningful error details from Ansible output
        local error_details
        error_details=$(extract_ansible_errors "${output_file}" "does not exist" "-B 1 -A 2")
        
        local error_message
        printf -v error_message "Backup playbook failed with exit code: %s\n\nDetails:\n%s" "${exit_code}" "${error_details}"
        error "${error_message}"
    fi

    # On success, clean up the temp file and disarm the trap
    rm -f -- "${output_file}"
    trap - EXIT HUP INT QUIT TERM
    
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
                else
                    echo "Error: Unexpected argument: $1" >&2
                    show_help >&2
                    exit 1
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
    
    log "========================================="
    log "Starting backup for app: ${app_name}"
    log "========================================="
    
    # Validate inputs using common functions
    validate_app_name "${app_name}" "true"  # allow 'all' for backups
    validate_path "${backup_dest}" "backup destination"
    validate_hostname "${target_host}"
    
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
    
    log "========================================="
    log "Backup completed successfully!"
    log "========================================="
}

main "$@"
