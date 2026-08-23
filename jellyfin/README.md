# Jellyfin

Self-hosted media server using the [official `jellyfin/jellyfin`](https://hub.docker.com/r/jellyfin/jellyfin) image.
Persistent config, cache, and media are mounted separately, with optional
AMD VA-API hardware acceleration.

## Prerequisites

Create the external networks required by the variant you intend to use:

```shell
docker network create proxy      # for COMPOSE_VARIANT=proxy or traefik_proxy
docker network create traefik    # for COMPOSE_VARIANT=traefik or traefik_proxy
```

For AMD VA-API hardware acceleration on the host (Linux), the
`/dev/dri/renderD128` device node must exist. See the upstream
[AMD hardware acceleration guide](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/amd/)
for kernel/driver requirements.

## Quick start

```shell
cd jellyfin
cp .env.dist .env
nano -w .env              # set HOST_MEDIA_DIR and (optionally) VIDEO_ACCEL_DEVICE / VIDEO_RENDER_GROUP
docker compose up -d
docker compose logs -f
```

The Web UI is then available at `http://127.0.0.1:8096` (or the
`TRAEFIK_HOST` you set when running the Traefik variants).

## First-run review

Jellyfin prompts for an admin user at first start. Configure libraries
under Dashboard → Libraries pointing at the internal mount paths (not
the host paths):

- `${INT_MEDIA_DIR:-/media}` — required, maps `HOST_MEDIA_DIR`
- `/libraries/<label>` — optional, one per `EXTRA_MOUNT_<N>` slot

Extras mount at `/libraries/<label>` (sibling tree of `/media`, not
nested inside it) to avoid shadowing the primary mount when a label
coincides with a subdirectory of the primary's host tree. Up to 4
additional media mounts are supported via `EXTRA_MOUNT_<N>` (host path)
and `EXTRA_MOUNT_<N>_LABEL` (in-container target suffix). Leave a slot
unset to skip it.

## Hardware acceleration

Enable AMD VA-API by setting both values in `.env`:

```dotenv
VIDEO_ACCEL_DEVICE=/dev/dri/renderD128
VIDEO_RENDER_GROUP=108    # getent group render | cut -d: -f3
```

`VIDEO_ACCEL_DEVICE` is passed through to the container's
`/dev/dri/renderD128`. `VIDEO_RENDER_GROUP` is added to `group_add` so the
container process can read the host render node regardless of which
numeric UID/GID is mapped via `HOST_USER`/`HOST_GROUP`.

After the stack is up, open Dashboard → Playback → Transcoding and set:

- **Hardware acceleration:** `Video Acceleration API (VAAPI)`
- **VA-API Device:** `/dev/dri/renderD128`

When `VIDEO_ACCEL_DEVICE` is left unset, the Compose `devices:` mapping
becomes a harmless `/dev/null → /dev/null` bind and Jellyfin transcodes
in software. The stack continues to work without a render node.

## SOCKS5 outbound proxy

The `proxy` and `traefik_proxy` variants join the external `proxy` Docker
network. To route outbound HTTP(S) traffic (TMDb, OMDb, plugin feeds)
through the repository's `mihomo` SOCKS5 listener, add to `.env`:

```dotenv
ALL_PROXY=socks5://mihomo:1050
HTTPS_PROXY=socks5://mihomo:1050
NO_PROXY=localhost,127.0.0.1
```

The variables are intentionally not defined in the Compose file so
deployments can use any reachable SOCKS5 endpoint, including endpoints
outside the Docker network. No transparent routing, TPROXY, or
`network_mode: host` is used for proxying — `ALL_PROXY` is enough.

## Variants

Set `COMPOSE_VARIANT` in `.env`:

| Variant         | Behavior                                                                                  |
|-----------------|-------------------------------------------------------------------------------------------|
| `default`       | Standalone localhost-bound container, bridge network only                                 |
| `proxy`         | Adds the external `proxy` network (use with `ALL_PROXY` for outbound via Mihomo)          |
| `traefik`       | Adds a Traefik router on the shared `websecure` entrypoint                                |
| `traefik_proxy` | Combines `traefik` and `proxy`                                                            |

Traefik variants use `TRAEFIK_HOST` as the public hostname and proxy the
internal HTTP service on `${WEBUI_INT_BIND_PORT:-8096}`. No WebSocket
hacks are needed.

## Network mode override

Set `NETWORK_MODE=host` in `.env` for host networking. When host
networking is active:

- Docker ignores the `ports:` mapping.
- The container cannot join the `proxy` or `traefik` external networks,
  so the `proxy`, `traefik`, and `traefik_proxy` variants stop working.

Use host mode only when you accept that trade-off (for example to reach
Jellyfin on the LAN without port forwarding). DLNA discovery is not a
goal here; do not enable host networking just for discovery.

## Port conflict with Emby

Both this stack and `emby/` default to host port `8096` (the upstream
default for both products). If you run both stacks on the same host,
change `WEBUI_BIND_PORT` on one of them (for example to `8097` for
Jellyfin) before starting the second one.
