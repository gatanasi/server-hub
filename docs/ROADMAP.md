# Roadmap

This document tracks planned services and infrastructure decisions.

For the current operational baseline, see [README.md](../README.md) and
`managed_apps` in
[ansible/inventory/production.yml](../ansible/inventory/production.yml).

## Status Legend

- [x] Done
- [ ] Planned
- [ ] Under evaluation (decision pending)

## Completed Foundation

- [x] DuckDNS
- [x] WireGuard (`wg-easy`)
- [x] Cloudflare Tunnel
- [x] Tailscale
- [x] Caddy
- [x] OpenSpeedTest (`openspeedtest`)
- [x] Video Converter (`video-converter`)
- [x] Stirling PDF (`stirling-pdf`)
- [x] ConvertX (`convertx`)

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

- [ ] k3s (under evaluation)
- [ ] Rancher (under evaluation)
- [ ] Argo CD vs Flux (under evaluation)
- [ ] Longhorn for Kubernetes backups (under evaluation)
- [ ] rclone + restic backup extension (under evaluation)
- [ ] Octopus (under evaluation)

## Next Milestones

1. Monitoring baseline: Uptime Kuma + InfluxDB + Grafana
2. Data protection hardening: rclone/restic backup replication
3. Optional Kubernetes pilot: k3s with GitOps controller evaluation
