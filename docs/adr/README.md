# Architecture Decision Records

One short record per significant platform decision. Format: Context → Decision
→ Consequences. Keep them under a page; link related ADRs.

| # | Decision | Status |
|---|----------|--------|
| [0001](0001-use-opentofu.md) | OpenTofu over Terraform | Accepted |
| [0002](0002-use-flux.md) | Flux over Argo CD | Accepted |
| [0003](0003-topology-1cp-2-workers.md) | Start with 1 control plane + 2 workers | Accepted |
| [0004](0004-storage-local-path-volsync.md) | local-path-provisioner + VolSync over Longhorn | Accepted |
| [0005](0005-keep-wg-easy-vpn.md) | Keep wg-easy as the VPN, on a dedicated VM | Accepted |
| [0006](0006-hybrid-vm-strategy.md) | Hybrid end-state: cluster + selected dedicated VMs | Accepted |
