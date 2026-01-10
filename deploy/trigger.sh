#!/usr/bin/env bash
#
# trigger.sh - SSH forced command dispatcher
#
# This script is the entry point for SSH forced commands from GitHub Actions.
# It dispatches to the appropriate handler based on the first argument.
#
# Usage (via forced SSH command):
#   ssh deployer@deployer.vm deploy <app-name>
#   ssh deployer@deployer.vm backup <app-name> [options]
#   ssh deployer@deployer.vm restore <app-name> <operation> [options]
#
# Legacy usage (for backward compatibility):
#   ssh deployer@deployer.vm <app-name>
#
# Security:
#   - This script is referenced by the forced command in authorized_keys
#   - It validates the operation before dispatching
#   - Each handler script has its own validation and logging
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Handle arguments from SSH_ORIGINAL_COMMAND or direct invocation
if [[ -n "${SSH_ORIGINAL_COMMAND:-}" ]]; then
    # Called via forced SSH command
    # shellcheck disable=SC2086
    set -- ${SSH_ORIGINAL_COMMAND}
fi

# Get the operation (first argument)
OPERATION="${1:-}"

# Dispatch based on operation
case "${OPERATION}" in
    deploy)
        shift
        exec "${SCRIPT_DIR}/trigger-deploy.sh" "$@"
        ;;
    backup)
        shift
        exec "${SCRIPT_DIR}/trigger-backup.sh" "$@"
        ;;
    restore)
        shift
        exec "${SCRIPT_DIR}/trigger-restore.sh" "$@"
        ;;
    "")
        echo "Usage: $0 <operation> [args...]"
        echo ""
        echo "Operations:"
        echo "  deploy <app-name>                     Deploy an application"
        echo "  backup <app-name> [options]           Backup application volumes"
        echo "  restore <app-name> <op> [options]     Restore application volumes"
        echo ""
        echo "For detailed help, run:"
        echo "  $0 deploy --help"
        echo "  $0 backup --help"
        echo "  $0 restore --help"
        exit 1
        ;;
    *)
        # Legacy mode: assume it's an app name for deployment
        exec "${SCRIPT_DIR}/trigger-deploy.sh" "$@"
        ;;
esac
