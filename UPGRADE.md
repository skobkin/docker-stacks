## 2026-05-12 - ESPHome networking hardened to host mode

### Affected stacks

- `esphome`

### Explanation

`network_mode` is now hardcoded to `host` and the overridable `NETWORK_MODE` variable has been removed. The container must always run in host networking mode to properly look for devices in the same network.

### Migration

Existing `.env` files that set `NETWORK_MODE=bridge` will silently be ignored — the stack now runs with `network_mode: host` regardless. Remove the `NETWORK_MODE` line from your local `.env` if present.

## 2026-05-12 - Emby WEBUI_BIND_ADDR now defaults to 127.0.0.1

### Affected stacks

- `emby`

### Explanation

`WEBUI_BIND_ADDR` default changed from `0.0.0.0` to `127.0.0.1`. The web UI will no longer bind to all interfaces on first start unless explicitly configured otherwise.

### Migration

To retain the old behavior, set `WEBUI_BIND_ADDR=0.0.0.0` in your local `.env`. If you plan to use Traefik with `COMPOSE_VARIANT=traefik`, the `127.0.0.1` default is recommended and no change is needed.

## 2026-05-02 - Traefik HTTP/3 enabled

### Affected stacks

- `traefik`

### Explanation

The shared Traefik `websecure` entrypoint now enables HTTP/3 by default and publishes UDP on the HTTPS port. Existing TCP HTTP and HTTPS behavior is unchanged.

### Migration

Allow UDP traffic to `HTTPS_UDP_BIND_PORT` if clients should use HTTP/3. If another service already owns that UDP port, change `HTTPS_UDP_BIND_PORT` or disable HTTP/3 in the local Traefik environment before recreating the stack.

## 2026-05-02 - Optional shared on-host database network added

### Affected stacks

- `castopod`
- `forgejo`
- `gotosocial`
- `hedgedoc`
- `magneticod`
- `magnetico-web`
- `miniflux`
- `synapse`
- `tg-rss-bot`
- `woodpecker`

### Explanation

These stacks can now opt into the shared external `databases` Docker network with `COMPOSE_VARIANT=databases`. Stacks that also support Traefik can use `COMPOSE_VARIANT=traefik_databases` to enable both optional network attachments.

The shared network is intended for bare-metal databases running on the Docker host and can also be used by shared database containers.

The default variants are unchanged and do not require the `databases` network.

### Migration

For a bare-metal host database, create the shared network with a stable gateway, for example `docker network create --subnet 172.30.10.0/24 --gateway 172.30.10.1 databases`. Make the database listen on `172.30.10.1`, allow clients from `172.30.10.0/24`, set the affected stack to `COMPOSE_VARIANT=databases` or `COMPOSE_VARIANT=traefik_databases`, and update the stack database host or DSN to use `172.30.10.1`.

For a shared database container, attach the database container to the `databases` network and use the database container name in the stack database host or DSN.
