# ADR 0002 — Use Flux (not Argo CD) as the GitOps engine

Status: Accepted (2026-07-19)

## Context

Requirement R2: merging a PR on GitHub is the only deploy action. The repo
already encrypts secrets with SOPS + age (`.sops.yaml`), uses a monorepo
layout (R4), and runs Renovate. The cluster runs on a single 64 GB host, so
controller footprint matters.

## Decision

Use Flux. Cluster entrypoint at `k8s/clusters/prod`, layered Kustomizations
with `dependsOn` (cilium → platform → apps), and native SOPS decryption via
kustomize-controller with the existing age key.

## Consequences

- The pre-cluster secrets workflow carries over unchanged — no new secret
  tooling. Argo CD would have required a plugin (KSOPS) or a tooling switch.
- Lighter footprint than Argo CD; no UI (acceptable: `flux` CLI + Grafana).
- Largest homelab GitOps reference ecosystem (kubesearch.dev) is Flux-based.
- Renovate's `flux` manager PRs chart/image bumps; merge = deploy.
