#!/bin/sh
# Script to interactively unlock non-boot ZFS datasets requiring a prompt (keylocation=prompt)

set -u # Exit on unset variable

# --- Find the root filesystem dataset ---
root_fs=$(zfs list -H -o name,mountpoint | awk '$2 == "/" { print $1; exit }')
if [ -z "$root_fs" ]; then
    echo "ERROR: Could not determine the root filesystem dataset mounted at '/'. Exiting." >&2
    exit 1
fi

# --- Identify the likely boot encryption root ---
boot_encryption_root=$(echo "$root_fs" | sed 's|/[^/]*$||')

# --- Find non-boot datasets where keylocation is 'prompt' ---
datasets_to_check=$(zfs get -H -o name,value keylocation | awk -v boot_root="$boot_encryption_root" '$2 == "prompt" && $1 != boot_root {print $1}')

# --- Print datasets found (or message if none) ---
if [ -z "$datasets_to_check" ]; then
    # No datasets found needing interactive unlock (that aren't the boot root)
    echo "INFO: No non-boot ZFS datasets found with keylocation=prompt to check." >&2
    exit 0
else
    # ADDED: Print datasets that will be checked
    echo "INFO: Found the following non-boot datasets with keylocation=prompt to check:" >&2
    # Use printf for potentially multi-line variable and sed to indent
    printf '%s\n' "$datasets_to_check" | sed 's/^/  /' >&2
    echo "---" >&2 # Separator
fi

# --- Iterate through identified datasets and check/unlock ---
action_taken=0 # Flag to track if any action was taken

for dataset in $datasets_to_check; do

    # Check the key status
    keystatus=$(zfs get -H -o value keystatus "$dataset" 2>/dev/null)
    get_status=$?

    if [ $get_status -ne 0 ]; then
         echo "WARN: Could not get keystatus for '$dataset'. Skipping." >&2
         continue
    fi

    if [ "$keystatus" = "unavailable" ]; then
        action_taken=1
        echo "ACTION: Dataset '$dataset' requires unlock. Attempting interactive prompt..."
        # Loop to allow retries on wrong password
        while true; do
            load_key_rc=0
            # Run 'zfs load-key' interactively
            (zfs load-key "$dataset") || load_key_rc=$?

            # Check if successful
            current_keystatus=$(zfs get -H -o value keystatus "$dataset")
            if [ "$load_key_rc" -eq 0 ] && [ "$current_keystatus" = "available" ]; then
                echo "SUCCESS: Key for '$dataset' loaded."
                break # Exit the retry loop for this dataset
            else
                # Failed or key still unavailable
                 if [ "$current_keystatus" != "available" ]; then
                    printf "WARN: Failed to load key for '%s'. Retry? (y/N): " "$dataset" >&2
                    read -r retry_choice < /dev/tty
                    case "$retry_choice" in
                        [Yy]*) continue ;; # Continue the while loop to retry
                        *) echo "INFO: Skipping unlock for '$dataset'." >&2; break ;; # Break loop, move to next dataset
                    esac
                 else
                    echo "SUCCESS: Key for '$dataset' loaded (checked after prompt)."
                    break
                 fi
            fi
        done
    # Optional: Uncomment if you want confirmation for already unlocked datasets
    # elif [ "$keystatus" = "available" ]; then
    #    action_taken=1 # Count showing info as an action if desired
    #    echo "INFO: Key for '$dataset' is already loaded." >&2
    fi
done

# Removed the final summary block for less verbosity by default

exit 0