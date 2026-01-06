# Docker Volume Backup Strategy

This document describes the backup and restore strategy for Docker volumes across all managed applications.

## Overview

All persistent data is stored in **Docker named volumes** on each host. A centralized backup strategy copies these volumes to a shared NFS/SMB mount for disaster recovery.

### Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    n8n.vm       │     │    odoo.vm      │     │   pdf.vm        │
│  ┌───────────┐  │     │  ┌───────────┐  │     │  ┌───────────┐  │
│  │ postgres  │  │     │  │ postgres  │  │     │  │ stirling  │  │
│  │ n8n_data  │  │     │  │ odoo_data │  │     │  │   data    │  │
│  │ redis     │  │     │  └───────────┘  │     │  └───────────┘  │
│  └───────────┘  │     │                 │     │                 │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │     /mnt/backups        │
                    │   (NFS/SMB Share)       │
                    │                         │
                    │  ├── n8n.vm/            │
                    │  │   └── n8n/           │
                    │  │       ├── postgres_*.tar.gz
                    │  │       ├── n8n_*.tar.gz
                    │  │       └── redis_*.tar.gz
                    │  ├── odoo.vm/           │
                    │  │   └── odoo/          │
                    │  └── pdf.vm/            │
                    │       └── stirling-pdf/ │
                    └─────────────────────────┘
```

## Backup Playbook

### Usage

```bash
# Run from deployer.vm
cd ~/git/server-hub/ansible

# Backup all apps on all hosts
ansible-playbook playbooks/backup-docker-volumes.yml

# Backup specific application
ansible-playbook playbooks/backup-docker-volumes.yml -e "app_name=n8n"

# Backup all apps on specific host
ansible-playbook playbooks/backup-docker-volumes.yml -l n8n.vm

# Custom backup destination
ansible-playbook playbooks/backup-docker-volumes.yml -e "backup_destination=/mnt/nas/backups"

# Custom retention period (default: 7 days)
ansible-playbook playbooks/backup-docker-volumes.yml -e "backup_retention_days=14"
```

### What Gets Backed Up

For each application:

| Item | Description |
|------|-------------|
| Docker Volumes | All named volumes defined in docker-compose.yml |
| docker-compose.yml | Application configuration |
| .env file | Encrypted with host machine ID |

### Backup Process

1. **Stop** the application stack gracefully
2. **Create** tar.gz archives of each Docker volume
3. **Copy** docker-compose.yml and encrypted .env
4. **Start** the application stack
5. **Verify** services are healthy
6. **Cleanup** backups older than retention period
7. **Notify** via Telegram (if configured)

### Backup File Naming

```
/mnt/backups/{hostname}/{app_name}/{volume_name}_{timestamp}.tar.gz

Example:
/mnt/backups/n8n.vm/n8n/n8n_db_storage_20260106T143000.tar.gz
/mnt/backups/n8n.vm/n8n/n8n_n8n_storage_20260106T143000.tar.gz
/mnt/backups/n8n.vm/n8n/docker-compose_20260106T143000.yml
```

---

## Restore Playbook

### Usage

```bash
# List available backups for an app
ansible-playbook playbooks/restore-docker-volumes.yml \
  -e "app_name=n8n" \
  -e "list_only=true"

# Restore latest backup
ansible-playbook playbooks/restore-docker-volumes.yml -e "app_name=n8n"

# Restore specific backup by timestamp
ansible-playbook playbooks/restore-docker-volumes.yml \
  -e "app_name=n8n" \
  -e "backup_timestamp=20260106T143000"

# Auto-confirm (for automation)
ansible-playbook playbooks/restore-docker-volumes.yml \
  -e "app_name=n8n" \
  -e "auto_confirm=true"
```

### Restore Process

1. **List** available backups with timestamps
2. **Confirm** restore action (unless auto_confirm=true)
3. **Stop** the application stack
4. **Clear** existing volume data
5. **Extract** backup archives to volumes
6. **Start** the application stack
7. **Verify** services are healthy

---

## Setup Requirements

### 1. Mount Backup Share

On each Docker host, mount the shared backup location:

```bash
# Create mount point
sudo mkdir -p /mnt/backups

# NFS mount
echo "nas.local:/volume1/backups /mnt/backups nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Or SMB/CIFS mount
echo "//nas.local/backups /mnt/backups cifs credentials=/root/.smbcreds,_netdev 0 0" | sudo tee -a /etc/fstab

# Mount
sudo mount -a

# Verify
df -h /mnt/backups
```

### 2. Telegram Notifications (Optional)

Create `~/.deploy-secrets` on deployer.vm:

```bash
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
```

---

## Scheduling Backups

### Option 1: Cron on Deployer VM

```bash
# Edit crontab on deployer.vm
crontab -e

# Daily backup at 3 AM
0 3 * * * cd ~/git/server-hub/ansible && ansible-playbook playbooks/backup-docker-volumes.yml >> ~/logs/backup.log 2>&1
```

### Option 2: n8n Workflow

Create an n8n workflow that:
1. Triggers daily via Schedule node
2. Runs the backup playbook via SSH Execute node
3. Sends notification on completion/failure

### Option 3: systemd Timer

Create `/etc/systemd/system/docker-backup.timer`:

```ini
[Unit]
Description=Daily Docker Volume Backup

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

---

## Disaster Recovery

### Scenario: Host VM Lost

1. Create new VM with same hostname
2. Install Docker and configure user
3. Mount backup share
4. Run deploy playbook to recreate app directory
5. Run restore playbook to recover data

```bash
# On new VM
sudo mkdir -p /mnt/backups
sudo mount -t nfs nas.local:/volume1/backups /mnt/backups

# On deployer.vm
ansible-playbook playbooks/deploy-docker-app.yml -e "app_name=n8n"
ansible-playbook playbooks/restore-docker-volumes.yml -e "app_name=n8n" -e "auto_confirm=true"
```

### Scenario: Corrupted Data

1. List available backups
2. Choose backup before corruption
3. Restore specific timestamp

```bash
# Find last good backup
ansible-playbook playbooks/restore-docker-volumes.yml -e "app_name=n8n" -e "list_only=true"

# Restore specific backup
ansible-playbook playbooks/restore-docker-volumes.yml \
  -e "app_name=n8n" \
  -e "backup_timestamp=20260105T030000"
```

---

## Monitoring

### Check Last Backup

```bash
# List latest backups for all apps
find /mnt/backups -name "*.tar.gz" -mtime -1 -ls
```

### Verify Backup Integrity

```bash
# Test extracting a backup without writing
tar -tzf /mnt/backups/n8n.vm/n8n/n8n_db_storage_20260106T143000.tar.gz > /dev/null && echo "OK"
```

### Space Usage

```bash
du -sh /mnt/backups/*/
```

---

## Security Considerations

1. **Encrypted .env files**: Environment files are encrypted with the host's machine ID
2. **Restricted permissions**: Backup directories use mode 0750
3. **Network security**: Ensure NFS/SMB share is only accessible from Docker hosts
4. **Retention policy**: Old backups automatically deleted after retention period

---

## Troubleshooting

### Backup Fails with "Volume not found"

```bash
# Check actual volume names
docker volume ls | grep <app_name>

# Volume names include project prefix
# e.g., "n8n_db_storage" not just "db_storage"
```

### Restore Fails with "Permission denied"

```bash
# Ensure backup mount is writable
touch /mnt/backups/test && rm /mnt/backups/test

# Check Docker socket permissions
ls -la /var/run/docker.sock
```

### Services Don't Start After Restore

```bash
# Check container logs
cd /opt/apps/<app_name>
docker compose logs

# Common issue: database needs time to recover
docker compose restart
```
