## Cluster firewall

```
[OPTIONS]

enable: 1

[ALIASES]

caddy 10.10.10.130
deployer 10.10.10.230
gateway 10.10.0.1 # UCG Fiber
gateway-v6 fe80::fcf2:13ff:febc:a282 # UCG Fiber IPv6
gateway-vm 10.10.10.1 # UCG Fiber VM
local-network 10.10.0.0/24
mac-mini 10.10.0.50
pve-01 10.10.10.10

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

[group from-caddy-proxy]

IN ACCEPT -source dc/caddy -p tcp -dport 8080 -log nolog
IN ACCEPT -source dc/caddy -p udp -dport 8080 -log nolog

[group tailscale]

IN ACCEPT -p tcp -dport 5252 -log nolog # Tailscale Web UI
IN ACCEPT -p udp -dport 41641 -log nolog

[group vpn-arg]

IN ACCEPT -p udp -dport 61249 -log nolog
IN ACCEPT -p tcp -dport 51821 -log nolog
IN ACCEPT -p udp -dport 41641 -log nolog
IN ACCEPT -p tcp -dport 5252 -log nolog

[group webserver]

IN Web(ACCEPT) -log nolog
IN ACCEPT -p udp -dport 80,443 -log nolog # Web UDP

[group wireguard]

IN ACCEPT -p udp -dport 62496 -log nolog
IN ACCEPT -p tcp -dport 51821 -log nolog # WG-Easy Web UI
```

## Windows 11

```
[OPTIONS]
enable: 1

[RULES]
IN RDP(ACCEPT) -log nolog
```
