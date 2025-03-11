#!/bin/sh

qm create 2000 --memory 2048 --cores 2 --cpulimit 2 --name alpine --cpu x86-64-v4 --machine q35,viommu=intel --ostype l26 --agent enabled=1 --net0 virtio,bridge=vmbr0,firewall=1 --onboot 1 --tags alpine --template 1
qm importdisk 2000 /var/lib/vz/template/iso/generic_alpine-3.21.2-x86_64-bios-cloudinit-r0.qcow2 local-zfs
qm set 2000 --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-2000-disk-0,discard=on,ssd=1
qm set 2000 --ide2 local-zfs:cloudinit
qm set 2000 --ciuser alpine
qm set 2000 --ipconfig0 ip=dhcp
qm set 2000 --boot c --bootdisk scsi0
qm set 2000 --serial0 socket --vga serial0
qm disk resize 2000 scsi0 4G
