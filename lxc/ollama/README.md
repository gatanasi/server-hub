# Proxmox Host
Download amdgpu_top to monitor resources
https://github.com/Umio-Yasuno/amdgpu_top/releases

# LXC
Follow the following guide to install Ryzen Software for Linux with ROCm
https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installryz/native_linux/install-ryzen.html

# Ollama
### /etc/pve/lxc/220.conf
```
arch: amd64
cores: 14
dev0: /dev/dri/renderD128,gid=992
dev1: /dev/dri/card1,gid=44
dev2: /dev/kfd,gid=992
features: keyctl=1,nesting=1
hostname: ollama
memory: 16384
net0: name=eth0,bridge=vmbr0,firewall=1,hwaddr=BC:24:11:71:38:04,ip=dhcp,tag=10,type=veth
onboot: 1
ostype: ubuntu
rootfs: local-zfs:subvol-220-disk-0,size=100G
swap: 0
tags: ubuntu
unprivileged: 1
```

### /etc/systemd/system/ollama.service.d/override.conf
```
[Service]
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.2"
Environment="HSA_ENABLE_COMPRESSION=1"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
Environment="OLLAMA_CONTEXT_LENGTH=131072"
Environment="OLLAMA_HOST=0.0.0.0:8080"
```