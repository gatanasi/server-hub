# OpenTofu — cluster provisioning (Layer 0)

Provisions the Talos Kubernetes cluster on Proxmox:

- `main.tf` — cluster definition; node counts and sizes are variables
- `modules/talos-node/` — one Proxmox VM booted from a Talos Image Factory image
- `talos.tf` — machine secrets, machine configs, bootstrap, kubeconfig output

Everything from bare Proxmox to a `kubectl`-reachable cluster is a single
`tofu apply`. See [docs/plan/phase-1.html](../docs/plan/phase-1.html) for the
build runbook.
