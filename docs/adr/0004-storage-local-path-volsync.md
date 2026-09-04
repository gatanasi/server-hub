# ADR 0004 — local-path-provisioner + VolSync (restic) instead of Longhorn

Status: Accepted (2026-07-19)

## Context

All cluster nodes are VMs on one physical host with consumer NVMe SSDs behind
ZFS. Replicated block storage (Longhorn, Rook-Ceph) would write every block
2–3× to the same physical disks — write amplification without real
redundancy — and add a resource-hungry control plane of its own. NVMe write
endurance is an explicit concern. Requirement R1 needs restorable per-app
backups, not synchronous replication.

## Decision

- App persistent volumes: `local-path-provisioner` (hostPath-backed PVs under
  `/var/local-path-provisioner` on workers).
- Backups: VolSync `ReplicationSource` per PVC using restic (`copyMethod:
  Direct`) to a repository on the NAS; restore via `ReplicationDestination`.
- Media: NFS from the NAS (never in block storage).
- Databases that need consistency guarantees can graduate to CloudNativePG
  with WAL archiving to the NAS.

## Consequences

- Minimal write path: one write hits one disk once; the biggest single saving
  for NVMe endurance in this design.
- No CSI snapshots and PVs are node-pinned; pods must be rescheduled with
  their node, and backups of running databases are crash-consistent unless
  handled at the app layer (dumps or CNPG).
- Durability comes from 3-2-1 backups (local restic repo on NAS + offsite
  copy), which the DR drill exercises — not from replication theater.
