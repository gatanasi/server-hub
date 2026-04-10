# Roadmap

This document tracks planned services and infrastructure decisions.

For the current operational baseline, see [README.md](../README.md) and `managed_apps` in [ansible/inventory/production.yml](../ansible/inventory/production.yml).

## Status Legend

- [x] Done
- [ ] Planned
- [?] Under evaluation

## Completed Foundation

- [x] DuckDNS
- [x] WireGuard (`wg-easy`)
- [x] Cloudflare Tunnel
- [x] Tailscale
- [x] Caddy
- [x] Open Speed Test
- [x] Video converter
- [x] Stirling PDF
- [x] ConvertX

## Active Docker App Catalog

These apps are currently mapped in inventory for deployment:

- [x] arr
- [x] caddy
- [x] convertx
- [x] filebrowser
- [x] immich
- [x] jellyfin
- [x] mediamanager
- [x] n8n
- [x] odoo
- [x] openspeedtest
- [x] stirling-pdf
- [x] video-converter
- [x] wg-easy

## Staged But Not Mapped Yet

Compose definitions exist, but these are not currently mapped in production inventory:

- [ ] dolibarr
- [ ] erpnext
- [ ] ghost

## Planned Services

- [ ] Invoice Ninja
- [ ] Homepage
- [ ] Uptime Kuma
- [ ] InfluxDB
- [ ] Grafana
- [ ] MinIO
- [ ] GoAccess
- [ ] Swiss invoicing workflow

## Platform Decisions

- [?] k3s
- [?] Rancher
- [?] Argo CD vs Flux
- [?] Longhorn for Kubernetes backups
- [?] rclone + restic backup extension
- [?] Octopus

## Next Milestones

1. Monitoring baseline: Uptime Kuma + InfluxDB + Grafana
2. Data protection hardening: rclone/restic backup replication
3. Optional Kubernetes pilot: k3s with GitOps controller evaluation
