qm create 2200 --memory 4096 --cores 2 --cpulimit 2 --name ubuntu --cpu x86-64-v4 --machine q35,viommu=intel --ostype l26 --agent enabled=1 --net0 virtio,bridge=vmbr0,firewall=1 --onboot 1 --tags ubuntu --template 1
qm importdisk 2200 /var/lib/vz/template/iso/oracular-server-cloudimg-amd64.img local-zfs
qm set 2200 --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-2200-disk-0,discard=on,ssd=1
qm set 2200 --ide2 local-zfs:cloudinit
qm set 2200 --ciuser ubuntu
qm set 2200 --ipconfig0 ip=dhcp
qm set 2200 --boot c --bootdisk scsi0
qm set 2200 --serial0 socket --vga serial0
qm disk resize 2200 scsi0 4G
