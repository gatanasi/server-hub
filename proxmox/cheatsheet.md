## Reduce writes on SSDs
```
zfs set atime=off rpool
zfs set xattr=sa rpool
zfs set logbias=throughput rpool

nano /etc/sysctl.conf
vm.swappiness=10
vm.vfs_cache_pressure=50
```

## Stop unnecessary services
```
systemctl stop corosync
systemctl stop pve-ha-crm
systemctl stop pve-ha-lrm
systemctl disable corosync
systemctl disable pve-ha-crm
systemctl disable pve-ha-lrm
```

## ~/.bashrc
```
export HISTSIZE=5000
export HISTFILESIZE=5000
```

## Send notifications on Telegram:
```
POST https://api.telegram.org/bot<TOKEN>>/sendMessage
Content-Type: application/json
{
  "chat_id": "<CHAT_ID>",
  "text": "{{ escape "⚠️ Proxmox ⚠️" }}\nTitle: {{ escape title }}\nSeverity: {{ escape severity }}\nMessage: {{ escape message }}"
}
```
