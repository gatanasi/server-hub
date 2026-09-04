# ADR 0006 — Hybrid end-state: Kubernetes cluster plus selected dedicated VMs

Status: Accepted (2026-07-19)

## Context

The migration's purpose is learning and industry relevance, not Kubernetes
maximalism. Some workloads have properties that fit a dedicated VM or LXC
better: hardware access (iGPU), independence from the cluster failure domain
(VPN), or simply no benefit from migration.

## Decision

The end-state is deliberately hybrid:

- **In-cluster**: most applications, migrated in waves (see docs/plan).
- **Dedicated VMs**: wg-easy (ADR 0005) and any app whose migration cost
  exceeds its benefit — decided per app at each wave checkpoint, recorded in
  the wave table. Jellyfin is the most likely candidate if iGPU passthrough
  proves not worth it.
- **LXC on the host**: ollama (direct iGPU access).

`docker/` and `ansible/` therefore shrink but are not deleted: they remain
the deploy mechanism for VM-resident apps.

## Consequences

- "Right workload, right platform" is an explicit, defensible position — the
  interview answer is that platform choice is a per-workload engineering
  decision, not an ideology.
- Two deploy mechanisms coexist permanently (Flux for the cluster, the
  existing Ansible flow for VMs); the VM set must stay small enough that this
  stays cheap.
- The Ansible inventory remains the source of truth for what runs on VMs.
