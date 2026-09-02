# Gopeed

[Gopeed](https://github.com/GopeedLab/gopeed) ([website](https://gopeed.com)) is a download
manager supporting HTTP(S), BitTorrent, magnet links and eD2k, with a built-in web UI and
REST API.

> [!NOTE]
> The image is published in the personal `liwei2633` Docker Hub namespace (linked from the
> upstream README), so pin and bump `IMAGE_TAG` deliberately.

## Quick start

```bash
cp .env.dist .env
# edit .env: set AUTH_PASSWORD before the first start
mkdir -p config downloads
docker compose up -d
```

The web UI is then available at http://127.0.0.1:8421 (see [PORTS.md](../PORTS.md)).

## Files

| Host path           | Container path   | Contents                            |
|---------------------|------------------|-------------------------------------|
| `HOST_CONFIG_DIR`   | `/app/storage`   | Settings database and task state    |
| `HOST_DOWNLOADS_DIR`| `/app/Downloads` | Downloaded files                    |

Both directories are bind mounts, so the image's implicit `/app/storage` volume is
satisfied explicitly and no anonymous volumes are created.

## User and permissions

The upstream image starts as root, runs `chown -R ${PUID}:${PGID} /app` and then drops
privileges with `su-exec`. For that reason a compose `user:` key is not supported — the
`PUID`/`PGID` (`HOST_USER`/`HOST_GROUP`) and `UMASK` environment variables are the only way
to control the runtime user. Note that the recursive `chown` walks the downloads directory
on every start, which can be slow for large libraries.

## Web UI authentication

Authentication is configured with `AUTH_USER`/`AUTH_PASSWORD`. An empty password disables
authentication, so the stack ships fail-closed: `AUTH_PASSWORD` must be set explicitly
before the first start. When authentication is enabled, REST API clients additionally need
`GOPEED_APITOKEN` (Settings -> API token in the UI). Keep in mind that environment values
are readable via `docker inspect`.

## BitTorrent peer port

Gopeed's BitTorrent listen port defaults to an ephemeral port chosen at runtime (managed in
the web UI and persisted in the settings database), so no peer port is published by this
compose file. To make the port stable for NAT/port-forwarding, pin it in the web UI
(Settings -> BitTorrent) and add a matching `ports:` entry manually, e.g.
`"6881:6881/tcp"` plus the UDP equivalent, with a row in [PORTS.md](../PORTS.md).

## Outbound proxy

Downloads can be routed through a SOCKS5/HTTP proxy — typically the `mihomo` service on the
shared proxy network. Set `COMPOSE_VARIANT=proxy` (or `traefik_proxy`) so the container
joins the proxy network, then configure the target with:

- `GOPEED_PROXY_ENABLE` — seed the global proxy as enabled (`false` by default)
- `GOPEED_PROXY_SCHEME` — `socks5` or `http`
- `GOPEED_PROXY_HOST` / `GOPEED_PROXY_PORT` — defaults `mihomo:1050`

These values seed Gopeed's global proxy setting on **first start only**; the downloader
config is persisted in the settings database afterwards, so later proxy changes are made in
the web UI (Settings -> Proxy), not via `.env`. Individual tasks may override the global
proxy. Enabling the proxy without joining the proxy network will break downloads, because
the proxy host is unreachable from the default bridge.

## Traefik

Set `COMPOSE_VARIANT=traefik` or `traefik_proxy` to add the routing labels and join the
external Traefik network. `TRAEFIK_HOST` must be set to the public hostname. The localhost
port publishing stays enabled in all variants. See
[_docs/traefik.md](../_docs/traefik.md) and [_docs/traefik_network.md](../_docs/traefik_network.md).

## Docs

- [PORTS.md](../PORTS.md)
