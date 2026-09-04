# ADR 0005 — Keep wg-easy as the VPN, on a dedicated VM

Status: Accepted (2026-07-19)

## Context

No service is exposed publicly: everything is LAN-only or reached through the
owner's own VPN. The UCG-Fiber gateway offers a native WireGuard server, but
wg-easy's per-client management UI is in active use. Remote access is the tool
you need most when the cluster is broken.

## Decision

Keep wg-easy, running on its dedicated VM outside the cluster. Do not migrate
it into Kubernetes.

## Consequences

- VPN access survives any cluster failure — it stays out of the failure
  domain it is used to reach and repair.
- One of the permanently VM-resident services under ADR 0006; its compose
  file and Ansible-based deploy flow remain.
- The UCG-Fiber native WireGuard server remains available as a documented
  fallback path if the wg-easy VM itself is down.
