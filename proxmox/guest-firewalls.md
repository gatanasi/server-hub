# Proxmox Guest Firewalls

## VMID 100
- Hostname: windows11
- Type: qemu
- Firewall rules
```text
GROUP common-noise
GROUP windows
GROUP common-logging
```

## VMID 111
- Hostname: ghost
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
GROUP common-logging
```

## VMID 112
- Hostname: odoo
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
GROUP common-logging
```

## VMID 113
- Hostname: erpnext
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
GROUP common-logging
```

## VMID 114
- Hostname: convertx
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
GROUP common-logging
```

## VMID 120
- Hostname: stirling-pdf
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
GROUP common-logging
```

## VMID 160
- Hostname: immich
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
GROUP common-logging
```

## VMID 200
- Hostname: openspeedtest
- Type: lxc
- IP: 10.10.10.200
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP webserver
GROUP common-logging
```

## VMID 202
- Hostname: video-converter
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
GROUP common-logging
```

## VMID 220
- Hostname: ollama
- Type: lxc
- IP: 10.10.10.220
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
GROUP common-logging
```

## VMID 221
- Hostname: llamacpp
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP common-logging
```

## VMID 229
- Hostname: github-runner
- Type: qemu
- IP: 10.10.10.229
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP common-logging
```

## VMID 230
- Hostname: deployer
- Type: qemu
- IP: 10.10.10.230
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
IN SSH(ACCEPT) -source dc/github-runner -log info
GROUP common-logging
```

## VMID 249
- Hostname: vpn-arg
- Type: qemu
- IP: 10.10.10.249
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP vpn-arg
GROUP common-logging
```

## VMID 250
- Hostname: wireguard
- Type: qemu
- IP: 10.10.10.250
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP wireguard
GROUP common-logging
```

## VMID 251
- Hostname: tailscale
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP tailscale
GROUP common-logging
```

## VMID 252
- Hostname: cloudflare
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP common-logging
```

## VMID 301
- Hostname: caddy
- Type: qemu
- IP: 10.10.10.130
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP webserver
GROUP common-logging
```

## VMID 310
- Hostname: n8n
- Type: qemu
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
GROUP common-logging
```

## VMID 500
- Hostname: jellyfin
- Type: lxc
- IP: 10.10.10.50
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
IN ACCEPT -p udp -dport 7359 -log nolog
GROUP common-logging
```

## VMID 501
- Hostname: arr
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
IN ACCEPT -source dc/local-network -log nolog
GROUP arr-stack
GROUP vm-isolation
GROUP common-logging
```

## VMID 600
- Hostname: filebrowser
- Type: lxc
- Firewall rules
```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
GROUP common-logging
```
