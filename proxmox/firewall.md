## Cluster firewall
```
[OPTIONS]
enable: 1

[ALIASES]
gateway 10.10.0.1 # UCG Fiber
gateway-v6 fe80::fcf2:13ff:febc:a282 # UCG Fiber IPv6
gateway-vm 10.10.10.1 # UCG Fiber VM
local-network 10.10.0.0/24
proxmox 10.10.0.200
caddy 10.10.10.130

[IPSET ubiquiti-gateway]
dc/gateway
dc/gateway-v6
dc/gateway-vm

[RULES]
IN Ping(ACCEPT) -log nolog
IN SSH(ACCEPT) -source 10.10.0.50 -log nolog
IN ACCEPT -p tcp -dport 8006 -log nolog # Proxmox GUI
IN ACCEPT -source +dc/ubiquiti-gateway -p udp -dport 10001 -log nolog
IN DROP -dest 10.10.0.255 -p udp -log nolog # Subnet broadcast
IN DROP -dest 255.255.255.255 -p udp -log nolog # Limited broadcast
IN DROP -log debug

[group ollama]
IN Ping(ACCEPT) -log nolog
IN ACCEPT -source dc/caddy -p tcp -dport 11434 -log nolog
IN ACCEPT -source dc/caddy -p udp -dport 11434 -log nolog

[group tailscale]
IN Ping(ACCEPT) -log nolog
IN ACCEPT -p tcp -dport 5252 -log nolog # Tailscale Web UI
IN ACCEPT -p udp -dport 41641 -log nolog

[group webserver]
IN Ping(ACCEPT) -log nolog
IN Web(ACCEPT) -log nolog
IN ACCEPT -p udp -dport 80 -log nolog
IN ACCEPT -p udp -dport 443 -log nolog
IN ACCEPT -p tcp -dport 3000 -log nolog

[group wireguard]
IN Ping(ACCEPT) -log nolog
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
