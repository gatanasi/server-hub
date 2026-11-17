# Homepage Dashboard

[Homepage](https://gethomepage.dev/) is the landing page for the homelab: one tile per
service with live data from its API, an up/down check, and the state of the Proxmox guest
it runs on.

- Definition: [docker/homepage/](../docker/homepage)
- Served at: `https://homepage.home.<domain>` (Caddy route `@homepage`)
- Runs on: `homepage.vm` (`managed_apps` in
  [ansible/inventory/production.yml](../ansible/inventory/production.yml))
- Version: v2.8.0, pinned by digest; Renovate proposes updates

## Design Decisions

| Decision | Why | Cost |
|---|---|---|
| Dedicated guest `homepage.vm` | Same one-app-per-guest pattern as everything else. The dashboard holds an API key for every service, so it does not share a guest with the internet-facing proxy. | One more guest to patch. |
| Widgets query apps through Caddy (`https://<app>.home.<domain>`) | No target guest needs a new inbound firewall rule; the status dot shows what a user actually gets. | Caddy down means every Caddy-fronted tile shows down. |
| arr.vm apps are queried directly (`http://arr.vm:<port>`) | They have no Caddy route, and the `arr-stack` group already allows those ports from the VM network. | Plain HTTP inside the VM network. |
| Guest status from the Proxmox API, not Docker | One read-only `PVEAuditor` token covers every guest. The alternative is a Docker API exposed on each of ~15 guests. | Shows the guest, not the individual container. |
| No Docker socket in the container | Nothing to discover on a single-app guest, and the socket is root on the host. | None. |
| Config mounted read-only, logs to stdout only | Git is the only writer of the config, and the app writes nothing to disk. | All nine config files must exist in the repo, even the empty ones. |
| Built-in password gate (`HOMEPAGE_AUTH_ENABLED`) | The API proxy returns data from every service to whoever can load the page. | One login per browser. Homepage does not rate-limit password attempts, so keep the hostname internal. |
| No Caddy widget | It reads Caddy's admin API, which is unauthenticated and can replace the whole proxy config. | The Caddy tile only has an end-to-end health check and guest stats. |

## First Deployment

A push that touches `docker/**` deploys immediately, so finish steps 1 to 5 **before**
merging. Until the guest exists, the `homepage` deploy job fails at the SSH step; nothing
else is affected.

### 1. Provision the guest

Create the guest as for any other app: Docker Engine with Compose v2, a `homepage` user in
the `docker` group, `/opt/apps/homepage` owned by it, `jq` and `rsync` installed, and the
deployer's SSH key authorised. See Part 5 of [GITOPS_SETUP.md](GITOPS_SETUP.md).

512 MB of memory and one core are enough; the container is capped at that.

The container runs as UID 1000 and only reads its config, so it works with or without
Docker's `userns-remap`.

### 2. DNS

| Name | Points to |
|---|---|
| `homepage.vm` | the new guest |
| `homepage.home.<domain>` | Caddy (`10.10.10.130`), unless a wildcard already covers it |

The Homepage container must also resolve `<app>.home.<domain>` to Caddy's internal
address. Check from the guest: `getent hosts jellyfin.home.<domain>`.

### 3. Proxmox firewall

Not applied or tested by the agent that wrote this; review before pasting.

`/etc/pve/firewall/cluster.fw`:

```ini
[ALIASES]
homepage 10.10.10.<n>

[RULES]
# before "GROUP common-logging"
IN ACCEPT -source dc/homepage -p tcp -dport 8006 -log nolog # Homepage, read-only API token
```

The second rule is needed because the Proxmox API is currently reachable from
`local-network` only.

Guest firewall for `homepage`:

```text
GROUP common-noise
GROUP common-allow
GROUP from-caddy-proxy
GROUP common-logging
```

Do **not** add `vm-isolation`: it drops traffic to the VM network, which is exactly what
Homepage needs. To still limit what the guest holding every API key can reach, use an
explicit allow-list instead (needs `arr` and `openspeedtest` aliases):

```ini
[group homepage-egress]

OUT ACCEPT -dest dc/gateway-vm -log nolog # DNS, UniFi API
OUT Web(ACCEPT) -dest dc/caddy -log nolog # every Caddy-fronted app
OUT ACCEPT -dest dc/arr -p tcp -dport 8080,8989,7878,9696,6767,8191,3000 -log nolog
OUT ACCEPT -dest dc/pve-01 -p tcp -dport 8006 -log nolog
OUT Web(ACCEPT) -dest dc/openspeedtest -log nolog
OUT DROP -dest dc/vm-network -log nolog
OUT DROP -dest dc/local-network -log nolog
```

Internet egress stays open in both variants: the Tailscale and Cloudflare widgets call
those vendors' public APIs, and icons are fetched by the browser, not the container.

Afterwards, record the guest in [proxmox/guest-firewalls.md](../proxmox/guest-firewalls.md)
and the alias and rule in [proxmox/firewall.md](../proxmox/firewall.md).

### 4. Create credentials

Use a dedicated, read-only credential wherever the service offers one. Variable names are
in [docker/homepage/.env.example](../docker/homepage/.env.example).

| Service | Create | Notes |
|---|---|---|
| Homepage | `HOMEPAGE_AUTH_PASSWORD`, `HOMEPAGE_AUTH_SECRET` (`openssl rand -base64 32`) | Secret must be at least 32 characters or the login refuses to start. |
| Proxmox | User, group with `PVEAuditor` on `/`, API token with privilege separation | Steps: <https://gethomepage.dev/configs/proxmox/#create-token> |
| Jellyfin | Dashboard > Advanced > API Keys | |
| Seerr | Settings > General > API Key | |
| Immich | Account Settings > API Keys, permission `server.statistics` | Must belong to an admin. |
| Radarr, Sonarr, Prowlarr, Bazarr | Settings > General > API Key | The first two are already in `docker/arr/.env.enc`. |
| qBittorrent | WebUI username and password | API keys exist only from qBittorrent 5.2.0. |
| Filebrowser | A user with no permissions beyond reading | |
| wg-easy | Admin username and password | No read-only role exists in v15. |
| Tailscale | API access token + device ID of the subnet router | Access tokens expire (90 days at most); the tile shows an API error when it does. |
| Cloudflare | API token with only `Account > Cloudflare Tunnel > Read`, account ID, tunnel ID | |
| UniFi | API key of a local read-only admin | |

### 5. Encrypt the environment

```bash
cd docker/homepage
cp .env.example .env
$EDITOR .env
sops --input-type dotenv --output-type dotenv -e .env > .env.enc
rm .env
```

### 6. Deploy and verify

Merge to `main` (deploys `caddy` and `homepage`), or run
`./deploy/trigger.sh deploy homepage` on the deployer.

```bash
# On homepage.vm: container healthy, running as UID 1000, no config errors in the log
docker inspect --format '{{.State.Health.Status}}' homepage
docker logs homepage | grep -iE 'error|invalid'

# From the LAN: reachable through Caddy, and gated
curl -s -o /dev/null -w '%{http_code}\n' https://homepage.home.<domain>/api/healthcheck  # 200
curl -s -o /dev/null -w '%{http_code}\n' https://homepage.home.<domain>/                 # 307 to /auth/signin
```

Then sign in. A tile that shows **API Error** has a wrong key or cannot reach its URL;
click it for the upstream response. `Host validation failed` in the log means the name in
the browser is not `homepage.home.<domain>` (see `HOMEPAGE_ALLOWED_HOSTS` in the compose
file).

## Assumptions To Check

Checked against the running system on 2026-11-17: the node is named `pve-01`, the VMIDs
match `pct list` / `qm list`, and from the homepage guest `<app>.home.<domain>` resolves to
Caddy and `arr.vm`, Caddy and the UniFi gateway answer.

Still unverified: the health paths used for Immich (`/api/server/ping`), Filebrowser
(`/health`) and Ollama (`/api/tags`) come from those projects, not from this repo's compose
files. A wrong one only turns that tile's dot red.

Not on the dashboard: Ghost, ERPNext, Dolibarr and `insights` have Caddy routes but are not
in `managed_apps`. Unpackerr and Recyclarr have no web interface.

## Changing The Dashboard

Edit the files in `docker/homepage/config/` and push; the deploy recreates the container.
Widget options per service: <https://gethomepage.dev/widgets/>.

To add a service: add a tile to `services.yaml`, any new `HOMEPAGE_VAR_*` to `.env.example`
and `.env.enc`, and its group to the `layout` in `settings.yaml` if the group is new.

Rollback note: an automatic rollback restores `compose.yaml` and `.env`, not the `config/`
directory. A dashboard change that breaks parsing does not fail the healthcheck either
(Homepage shows the error on the page), so revert the commit to undo it.

## Optional: Gluetun Widget

Shows the VPN's public IP and country. It is off because it needs a change to the arr
stack, which restarts the VPN gateway on deploy:

1. On `arr.vm`, create `/opt/apps/arr/config/gluetun/auth/config.toml`, limited to the one
   route the widget reads (key from `docker run --rm qmcgaw/gluetun genkey`):

   ```toml
   [[roles]]
   name = "homepage"
   routes = ["GET /v1/publicip/ip"]
   auth = "apikey"
   apikey = "<key>"
   ```

2. In `docker/arr/compose.yaml`, publish the control server on `gluetun`: `- 8000:8000`.
3. Allow TCP 8000 to the arr guest from `dc/homepage`.
4. Add `HOMEPAGE_VAR_GLUETUN_KEY` to `docker/homepage/.env.enc` and uncomment the widget
   in `services.yaml`.

Reference: <https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/control-server.md>
