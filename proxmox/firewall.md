## Cluster firewall
```
[OPTIONS]
enable: 1

[ALIASES]
gateway 10.10.0.1 # UCG Fiber
local-network 10.10.0.0/24
proxmox 10.10.0.200

[RULES]
IN Ping(ACCEPT) -source dc/local-network -log nolog # Allow ping from local network
IN ACCEPT -p tcp -dport 8006 -log nolog # Proxmox GUI
IN SSH(ACCEPT) -source dc/proxmox -log nolog
IN SSH(ACCEPT) -source 10.10.0.50 -log nolog
IN ACCEPT -source dc/gateway -p udp -dport 10001 -log nolog
IN DROP -dest 10.10.0.255 -p udp -log nolog # Subnet broadcast
IN DROP -dest 255.255.255.255 -p udp -log nolog # Limited broadcast
IN DROP -log warning

[group tailscale]
IN Ping(ACCEPT) -log nolog
IN ACCEPT -p tcp -dport 443 -log nolog
IN ACCEPT -p udp -dport 3478 -log nolog
IN ACCEPT -p tcp -dport 5252 -log nolog # Tailscale Web UI
IN ACCEPT -p udp -sport 41641 -log nolog

[group webserver]
IN Ping(ACCEPT) -log nolog
IN Web(ACCEPT) -log nolog
IN ACCEPT -p udp -dport 80 -log nolog
IN ACCEPT -p udp -dport 443 -log nolog
```

## Wireguard VPN firewall
```
[OPTIONS]
enable: 1

[RULES]
IN Ping(ACCEPT) -log nolog
IN ACCEPT -p udp -dport 62496 -log nolog # Wireguard VPN
```

## Windows 11
```
[OPTIONS]
enable: 1

[RULES]
IN RDP(ACCEPT) -log nolog
```