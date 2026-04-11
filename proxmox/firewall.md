# Proxmox Firewall

## /etc/pve/firewall/cluster.fw
```ini
[OPTIONS]

enable: 1

[ALIASES]

caddy 10.10.10.130
deployer 10.10.10.230
gateway 10.10.0.1 # UCG Fiber
gateway-v6 fe80::fcf2:13ff:febc:a282 # UCG Fiber IPv6
gateway-vm 10.10.10.1 # UCG Fiber VM
github-runner 10.10.10.229
jellyfin 10.10.10.50
local-network 10.10.0.0/24
mac-mini 10.10.0.50
pve-01 10.10.10.10
vm-network 10.10.10.0/24
vpn-arg 10.10.10.249

[IPSET allowed-ssh]

dc/deployer
dc/mac-mini

[IPSET ubiquiti-gateway]

dc/gateway
dc/gateway-v6
dc/gateway-vm

[RULES]

GROUP common-noise
GROUP common-allow
IN ACCEPT -p tcp -dport 8006 -log nolog # Proxmox GUI
GROUP common-logging

[group arr-stack]

IN ACCEPT -source dc/vm-network -p tcp -dport 8080,8989,7878,8686,8787,9696,5055,6767,8191,3000 -log nolog
OUT ACCEPT -dest dc/jellyfin -p tcp -dport 8080 -log nolog
OUT ACCEPT -dest dc/vpn-arg -log nolog
OUT Web(ACCEPT) -dest dc/caddy -log nolog

[group common-allow]

IN Ping(ACCEPT) -log nolog
IN SSH(ACCEPT) -source +dc/allowed-ssh -log nolog

[group common-logging]

IN DROP -log debug # Log everything else

[group common-noise]

IN DROP -source +dc/ubiquiti-gateway -p udp -dport 10001 -log nolog # Ubiquiti Device Discovery
IN DROP -p udp -dport 2647 -log nolog # Ubiquiti Grimlock
IN DROP -p udp -dport 1900 -log nolog # Simple Service Discovery Protocol
IN DROP -p udp -dport 5355 -log nolog # LLMNR (Link-Local Multicast Name Resolution)
IN DROP -dest 10.10.0.255 -p udp -log nolog # Subnet broadcast
IN DROP -dest 255.255.255.255 -p udp -log nolog # Limited broadcast
IN DROP -p igmp -log nolog # IGMP Multicast
IN DROP -dest ff02::16 -p ipv6-icmp -log nolog # IPv6 Multicast Listener Discovery
IN MDNS(DROP) -log nolog

[group from-caddy-proxy]

IN ACCEPT -source dc/caddy -p tcp -dport 8080 -log nolog
IN ACCEPT -source dc/caddy -p udp -dport 8080 -log nolog

[group tailscale]

IN ACCEPT -p tcp -dport 5252 -log nolog # Tailscale Web UI
IN ACCEPT -p udp -dport 41641 -log nolog

[group vm-isolation]

OUT ACCEPT -dest dc/gateway-vm -log nolog
OUT DROP -dest dc/vm-network -log nolog
OUT DROP -dest dc/local-network -log nolog

[group vpn-arg]

IN ACCEPT -p udp -dport 61249 -log nolog
IN ACCEPT -p tcp -dport 51821 -log nolog
IN ACCEPT -p udp -dport 41641 -log nolog
IN ACCEPT -p tcp -dport 5252 -log nolog

[group webserver]

IN Web(ACCEPT) -log nolog
IN ACCEPT -p udp -dport 443 -log nolog # Web UDP

[group windows]

OUT ACCEPT -dest dc/gateway-vm -log nolog
IN RDP(ACCEPT) -source dc/local-network -log nolog
OUT ACCEPT -dest dc/caddy -log nolog
OUT DROP -dest dc/vm-network -log nolog
OUT DROP -dest dc/local-network -log nolog

[group wireguard]

IN ACCEPT -p udp -dport 62496 -log nolog
IN ACCEPT -p tcp -dport 51821 -log nolog # WG-Easy Web UI

```

## Guest firewalls
See [guest-firewalls.md](guest-firewalls.md) for VM/CT firewall details.
