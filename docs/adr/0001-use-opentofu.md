# ADR 0001 — Use OpenTofu (not Terraform) for infrastructure provisioning

Status: Accepted (2026-07-19)

## Context

The homelab needs repeatable provisioning of Proxmox VMs and the Talos cluster
(requirement R1: rebuild from scratch in hours). Terraform relicensed to BUSL
in 2023; OpenTofu is the Linux Foundation fork under MPL-2.0, drop-in
compatible with the same providers and HCL.

## Decision

Use OpenTofu with the `bpg/proxmox` and `siderolabs/talos` providers. All
cluster infrastructure lives in `tofu/`.

## Consequences

- Skills and code transfer 1:1 to Terraform shops; recruiters read HCL as HCL.
- Built-in state encryption is available.
- Nothing in this project needs HashiCorp-only features, so no functional loss.
