# ADR 0003 — Start with 1 control plane + 2 workers

Status: Accepted (2026-07-19)

## Context

Requirement R3: grow to 3 control planes + N workers or shrink to 1 node by
changing a variable. The cluster runs on a single physical host (Beelink SER9
MAX, 64 GB), so multi-master cannot survive the box dying regardless of etcd
member count. Legacy Docker VMs must keep running during the migration, making
RAM the binding constraint. etcd is the most fsync-heavy component and NVMe
write endurance is a stated concern (see ADR 0004).

## Decision

Run 1 control plane (scheduling disabled) + 2 workers. Node counts and sizes
are OpenTofu variables. The cluster endpoint is a Talos shared VIP so the
control plane can scale 1→3→1 without regenerating configs.

## Consequences

- ~8 GB of RAM and two extra etcd write streams saved versus 3 control planes.
- HA mechanics (quorum, member add/remove, drains) are practiced via temporary
  scale drills, not paid for permanently.
- Single etcd member means control-plane downtime if cp-1's VM dies; recovery
  is `tofu apply` + etcd snapshot restore, which the DR runbook covers.
