# Kubernetes manifests — reconciled by Flux

Everything under this directory is applied to the cluster by Flux; nothing is
`kubectl apply`'d by hand except during bootstrap.

- `clusters/prod/` — Flux entrypoint: the Kustomizations that define layer
  ordering (cilium → platform → apps) with `dependsOn`
- `infrastructure/` — platform components: Cilium, cert-manager, ingress-nginx,
  local-path-provisioner, VolSync, NFS CSI, monitoring
- `apps/<app>/` — one directory per application (HelmRelease or kustomize),
  including its `*.sops.yaml` secrets (encrypted with the repo's existing
  SOPS + age setup)

Deployment model: merge a PR on `main` → Flux reconciles. See
[docs/plan/phase-2.html](../docs/plan/phase-2.html) onwards.
