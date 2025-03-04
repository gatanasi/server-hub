qm create 2100 --memory 4096 --cores 2 --cpulimit 2 --name debian --cpu x86-64-v4 --machine q35,viommu=intel --ostype l26 --agent enabled=1 --net0 virtio,bridge=vmbr0,firewall=1 --onboot 1 --tags debian --template 1
qm importdisk 2100 /var/lib/vz/template/iso/debian-12-generic-amd64.qcow2 local-zfs
qm set 2100 --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-2100-disk-0,discard=on,ssd=1
qm set 2100 --ide2 local-zfs:cloudinit
qm set 2100 --ciuser debian
qm set 2100 --ipconfig0 ip=dhcp
qm set 2100 --boot c --bootdisk scsi0
qm set 2100 --serial0 socket --vga serial0
qm disk resize 2100 scsi0 4G
