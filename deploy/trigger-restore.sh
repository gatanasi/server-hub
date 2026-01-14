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
#   --timestamp <TIMESTAMP>   Backup timestamp for restore_specific (format: YYYYMMDDThhmmss, e.g., 20260106T143000)
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

LOG_DIR="${HOME}/logs/restores"
LOG_FILE="${LOG_DIR}/restore-$(date +%Y%m%d-%H%M%S).log"
export OPERATION_TYPE="Restore"

# shellcheck source=deploy/common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# Functions
# ============================================================================

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
    echo "  --timestamp <TS>        Backup timestamp for restore_specific (YYYYMMDDThhmmss, e.g., 20260106T143000)"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 n8n list_backups"
    echo "  $0 n8n restore_latest"
    echo "  $0 n8n restore_specific --timestamp 20260106T143000"
}

run_restore_playbook() {
    local app="$1"
    local restore_op="$2"
    local backup_src="$3"
    local timestamp="$4"
    
    log "Running restore playbook for app: ${app}, operation: ${restore_op}"
    
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
    
    # Run the restore playbook in a subshell to avoid cd side effects
    # Create temporary file for Ansible output
    output_file=$(mktemp)
    trap 'rm -f -- "$output_file"' EXIT
    local exit_code=0
    (
        cd "${ANSIBLE_DIR}" || exit 1
        ansible-playbook "${ansible_args[@]}" 2>&1
    ) | tee -a "${LOG_FILE}" | tee "${output_file}" || exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        # Extract meaningful error details from Ansible output
        local error_details
        error_details=$(extract_ansible_errors "${output_file}" "No backups found|not found|does not exist")
        
        local error_message
        printf -v error_message "Restore playbook failed with exit code: %s\n\nDetails:\n%s" "${exit_code}" "${error_details}"
        error "${error_message}"
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
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    echo "Error: --source requires a path argument"
                    show_help
                    exit 1
                fi
                backup_src="$2"
                shift 2
                ;;
            --timestamp)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    echo "Error: --timestamp requires a timestamp argument (YYYYMMDDThhmmss, e.g., 20260106T143000)"
                    show_help
                    exit 1
                fi
                timestamp="$2"
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
                else
                    echo "Error: Unexpected argument: $1" >&2
                    show_help >&2
                    exit 1
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
    
    # Validate inputs using common functions
    validate_app_name "${app_name}"  # 'all' not allowed for restore
    
    # Validate restore operation
    if [[ ! "${restore_op}" =~ ^(list_backups|restore_latest|restore_specific)$ ]]; then
        error "Invalid restore operation: ${restore_op}. Must be list_backups, restore_latest, or restore_specific."
    fi
    
    # Validate backup source path
    validate_path "${backup_src}" "backup source"
    
    # Validate timestamp if restore_specific
    if [[ "${restore_op}" == "restore_specific" ]]; then
        if [[ -z "${timestamp}" ]]; then
            error "Timestamp is required for restore_specific operation. Use --timestamp YYYYMMDDThhmmss (e.g., 20260106T143000)"
        fi
        # Accept both uppercase and lowercase 'T' separator for user convenience
        if [[ ! "${timestamp}" =~ ^[0-9]{8}[Tt][0-9]{6}$ ]]; then
            error "Invalid timestamp format: ${timestamp}. Expected: YYYYMMDDThhmmss (e.g., 20260106T143000)"
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
    fi
    
    log "=========================================="
    log "Restore completed successfully!"
    log "=========================================="
}

main "$@"
