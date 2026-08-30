# LANquiry

LAN inventory and device monitor: polls a MikroTik router's RouterOS API
(DHCP leases, ARP, bridge host tables, wireless/CAPsMAN registrations) and,
with host networking, performs local mDNS/SSDP discovery. Read-only towards
the network — it never changes router configuration.

- Upstream: [github.com/skobkin/LANquiry](https://github.com/skobkin/LANquiry)
- Configuration reference: [docs/configuration.md](https://github.com/skobkin/LANquiry/blob/master/docs/configuration.md)
- Concepts (devices, findings, notifications): [docs/CONCEPTS.md](https://github.com/skobkin/LANquiry/blob/master/docs/CONCEPTS.md)

## Quick start

```shell
cd lanquiry
cp .env.dist .env
docker compose run --rm lanquiry hash-password   # paste the output into LANQUIRY_AUTH_ADMIN_PASSWORD_HASH
nano -w .env              # set the RouterOS source credentials (or comment them out)
mkdir -p data && sudo chown 100:100 data
docker compose up -d
docker compose logs -f
```

The image runs as non-root user/group `lanquiry` (uid/gid 100); the `chown`
gives it write access to the SQLite database directory. Verify with:

```shell
docker compose run --rm --entrypoint /bin/sh lanquiry -c 'id -u lanquiry'
```

Then open http://127.0.0.1:8420 (default `BIND_ADDRESS`/`BIND_PORT`), log in
as `admin`, and complete the setup wizard: review the detected networks and
classify the devices already observed.

To run with local discovery only, comment out the three
`LANQUIRY_SOURCES_ROUTEROS_0_*` variables in `.env`. The stack is configured
entirely through environment variables — no configuration file is mounted.
If you would rather keep the RouterOS credentials and the admin hash out of
the environment (they are readable via `docker inspect`), upstream supports a
`0600` configuration file started with `--config`; see
[docs/configuration.md](https://github.com/skobkin/LANquiry/blob/master/docs/configuration.md).

## Read-only RouterOS user

Create a dedicated API group and user on the router. `api` allows logging in
over the RouterOS API protocol, `read` allows read-only (`print`) commands:

```routeros
/user/group/add name=lanquiry policy=api,read
/user/add name=lanquiry-readonly group=lanquiry password="replace-with-a-long-random-password"
```

Check the result with `/user/group/print` — the group should list exactly
`api, read`. What the account deliberately cannot do: change configuration
(no `write`), manage users or policies (no `policy`), log in to the console
or Winbox (no `local`, `ssh`, `winbox`, `web`), reboot, run scripts or pings
(no `test`), or view stored passwords and keys (no `sensitive`).

The API service must be enabled and restricted to the LANquiry host:

```routeros
/ip/service/set api address=192.168.88.0/24
```

Prefer the TLS API service (`api-ssl`, port 8729, needs a certificate the
LANquiry host trusts) over the plain API (port 8728), and set
`LANQUIRY_SOURCES_ROUTEROS_0_TLS=true` in `.env` accordingly. Do not enable
`LANQUIRY_SOURCES_ROUTEROS_0_INSECURE_SKIP_VERIFY` in production.

LANquiry issues only these fixed read commands:

Poll cycle:

- `/ip/dhcp-server/lease/print`
- `/ip/arp/print`
- `/interface/bridge/host/print`
- `/interface/wireless/registration-table/print`
- `/caps-man/registration-table/print`

Setup wizard only (network proposal):

- `/ip/address/print`
- `/interface/vlan/print`
- `/ip/dhcp-server/network/print`
- `/ip/pool/print`

Wireless and CAPsMAN paths are skipped gracefully on routers without them;
`LANQUIRY_SOURCES_ROUTEROS_0_WIRELESS_DISABLED` /
`LANQUIRY_SOURCES_ROUTEROS_0_CAPSMAN_DISABLED` can disable them explicitly.

## Networking: bridge vs host

RouterOS polling is outbound TCP to 8728/8729, which works fine through the
Docker bridge. mDNS (UDP 5353) and SSDP (UDP 1900) are multicast and need
host networking, so they are force-disabled in the bridge variants.

| Variant        | Networking | Traefik | mDNS/SSDP | Use when                             |
|----------------|------------|---------|-----------|--------------------------------------|
| `default`      | bridge     | —       | disabled  | plain localhost-bound monitoring     |
| `traefik`      | bridge     | yes     | disabled  | UI behind Traefik, no local discovery |
| `host`         | host       | —       | enabled   | discovery on the host's LAN          |
| `traefik_host` | host       | yes     | enabled   | discovery plus Traefik               |

Switch variants by setting `COMPOSE_VARIANT` in `.env` and running
`docker compose up -d` again (the container is recreated). In the bridge
variants the app listens on `0.0.0.0:8080` inside the container and is
published at `${BIND_ADDRESS}:${BIND_PORT}` (default `127.0.0.1:8420`); in the
host variants the app binds `${BIND_ADDRESS}:${BIND_PORT}` directly on the
host.

With host networking, discovery uses the interface allowlist
(`LANQUIRY_DISCOVERY_INTERFACES`, default `auto`), which resolves the host's
live interfaces at startup and filters out container bridges, veth pairs, VPN
tunnels, and loopback. Host networking still cannot see devices on isolated
VLANs unless the host itself has an interface in that VLAN.

## Traefik

Both Traefik variants require:

```shell
TRAEFIK_HOST=lanquiry.example.com
LANQUIRY_HTTP_PUBLIC_BASE_URL=https://lanquiry.example.com   # https:// is required for non-loopback URLs
```

If Traefik terminates TLS in front of the app, also set
`LANQUIRY_HTTP_TRUSTED_PROXIES` to the Traefik network's CIDR so
forwarded-client headers are trusted:

```shell
docker network inspect traefik --format '{{(index .IPAM.Config 0).Subnet}}'
```

See [_docs/traefik.md](../_docs/traefik.md) and
[_docs/traefik_network.md](../_docs/traefik_network.md) for the repo-wide
Traefik setup, and the upstream
[reverse-proxy deployment notes](https://github.com/skobkin/LANquiry/blob/master/docs/deployment/reverse-proxy.md)
for proxy-related configuration details.

## Data and backup

All state lives in a SQLite database (WAL mode) under `data/` — expect
`lanquiry.db`, `lanquiry.db-wal`, and `lanquiry.db-shm` files. Stop the stack
before copying so the backup is consistent:

```shell
docker compose stop
cp -a data /path/to/backup/
docker compose start
```

Copying only `lanquiry.db` while the app is running can lose recent commits
still sitting in the WAL file.

## Docs

- Upstream repository: [github.com/skobkin/LANquiry](https://github.com/skobkin/LANquiry)
- Configuration reference (all `LANQUIRY_*` variables and defaults):
  [docs/configuration.md](https://github.com/skobkin/LANquiry/blob/master/docs/configuration.md)
- Image: [hub.docker.com/r/skobkin/lanquiry](https://hub.docker.com/r/skobkin/lanquiry)
- Port usage: [../PORTS.md](../PORTS.md)
