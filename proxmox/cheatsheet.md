## Reduce writes on SSDs
```
zfs set atime=off rpool
zfs set xattr=sa rpool

nano /etc/sysctl.conf
vm.swappiness=10
vm.vfs_cache_pressure = 50
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