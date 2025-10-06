#!/bin/sh

# --- Argument Handling ---
# Check if all required arguments were provided
if [ -z "$1" ]; then
  echo "Error: Please provide a VMID as the first argument."
  echo "Usage: $0 <VMID> <DISTRO> <IMAGE_PATH>"
  exit 1
fi
if [ -z "$2" ]; then
  echo "Error: Please provide a DISTRO name as the second argument."
  echo "Usage: $0 <VMID> <DISTRO> <IMAGE_PATH>"
  exit 1
fi
if [ -z "$3" ]; then
  echo "Error: Please provide the IMAGE_PATH as the third argument."
  echo "Usage: $0 <VMID> <DISTRO> <IMAGE_PATH>"
  exit 1
fi

# Assign arguments to variables for clarity
VMID="$1"
DISTRO="$2"
IMAGE_PATH="$3"

# --- Template Creation ---
echo "Creating VM ${VMID} for ${DISTRO} from image ${IMAGE_PATH}..."
qm create "${VMID}" --memory 4096 --cores 4 --cpulimit 4 --name "${DISTRO}" --cpu x86-64-v4 --machine q35,viommu=intel --ostype l26 --agent enabled=1 --net0 virtio,bridge=vmbr0,firewall=1,tag=10 --onboot 1 --tags "${DISTRO}" --template 1

# --- Secure Boot Logic ---
# Determine if Secure Boot should be enabled based on Distro
ENABLE_SECURE_BOOT="true"
if [ "${DISTRO}" = "alpine" ]; then # Add other distros here if needed
  ENABLE_SECURE_BOOT="false"
fi

# Set BIOS and EFI Disk (conditionally add pre-enrolled-keys)
EFI_DISK_BASE="local-zfs:1,efitype=4m"
if [ "${ENABLE_SECURE_BOOT}" = "true" ]; then
  echo "Enabling Secure Boot (adding pre-enrolled keys)."
  qm set "${VMID}" --bios ovmf --efidisk0 "${EFI_DISK_BASE},pre-enrolled-keys=1"
else
  echo "Disabling Secure Boot (omitting pre-enrolled keys)."
  qm set "${VMID}" --bios ovmf --efidisk0 "${EFI_DISK_BASE}"
fi

# --- Continue with VM Configuration ---
echo "Importing disk image..."
qm importdisk "${VMID}" "${IMAGE_PATH}" local-zfs

echo "Configuring storage and boot options..."
qm set "${VMID}" --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-"${VMID}"-disk-1,discard=on,ssd=1
qm set "${VMID}" --ide2 local-zfs:cloudinit
qm set "${VMID}" --ciuser "${DISTRO}"
qm set "${VMID}" --ipconfig0 ip=dhcp
qm set "${VMID}" --boot c --bootdisk scsi0
qm set "${VMID}" --serial0 socket --vga serial0

echo "Resizing disk..."
qm disk resize "${VMID}" scsi0 5G

echo "VM template ${VMID} (${DISTRO}) created successfully."

exit 0