#!/bin/sh

# Check if a VMID was provided
if [ -z "$VMID" ]; then
  echo "Error: Please provide a VMID as the first argument."
  exit 1
fi

qm create "$VMID" --memory 4096 --cores 2 --cpulimit 2 --name "$DISTRO" --cpu x86-64-v4 --machine q35,viommu=intel --ostype l26 --agent enabled=1 --net0 virtio,bridge=vmbr0,firewall=1,tag=10 --onboot 1 --tags "$DISTRO" --template 1
qm set "$VMID" --bios ovmf --efidisk0 local-zfs:1,efitype=4m,pre-enrolled-keys=1
qm importdisk "$VMID" "$IMAGE_PATH" local-zfs
qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-"$VMID"-disk-1,discard=on,ssd=1
qm set "$VMID" --ide2 local-zfs:cloudinit
qm set "$VMID" --ciuser "$DISTRO"
qm set "$VMID" --ipconfig0 ip=dhcp
qm set "$VMID" --boot c --bootdisk scsi0
qm set "$VMID" --serial0 socket --vga serial0
qm disk resize "$VMID" scsi0 5G
