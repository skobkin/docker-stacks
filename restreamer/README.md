# Restreamer

[Restreamer](https://docs.datarhei.com/restreamer) is a self-hosted live streaming and restreaming platform with a web UI, built-in player/publication pages, and RTMP/SRT ingest support.

## Setup

```shell
cp .env.dist .env
nano -w .env
docker compose up -d
```

This stack stores mutable state in:

- `./config` for Restreamer configuration and generated state
- `./data` for media data and other runtime files

The stack uses the explicit stable image tag `2.12.0` by default.

## Exposure Model

- The web UI is always published on `127.0.0.1:${HTTP_BIND_PORT}` and maps to container port `8080`.
- `COMPOSE_VARIANT=traefik` adds host-based routing for the same HTTP service through the shared Traefik stack.
- RTMP ingest is published directly on `${RTMP_BIND_PORT}`.
- SRT ingest is published directly on `${SRT_BIND_PORT}/udp`.
- Built-in HTTPS/Let's Encrypt and RTMPS are intentionally not wired in this v1 stack.

When using Traefik, leave Restreamer's own HTTPS and Let's Encrypt support disabled. Upstream documents reverse proxying the HTTP interface without enabling Restreamer TLS, and the shared `websecure` entrypoint already handles certificates for the UI.

## First Run

Upstream quick-start docs refer to the default credentials `admin` / `datarhei`. Sign in, then change the password immediately in Restreamer.

The compose file only publishes the ingest ports. The internal RTMP and SRT servers are enabled from Restreamer's UI:

- use the setup wizard for a quick initial source configuration
- or enable RTMP/SRT under the system settings later

This keeps the stack flexible for the common passthrough/copy-mode case where you restream an incoming source as-is to one or two outputs.

## Traefik

To proxy the web UI through the shared Traefik stack:

1. Set `COMPOSE_VARIANT=traefik` in `.env`.
2. Set `TRAEFIK_HOST` to the desired host name.
3. Adjust `TRAEFIK_ENTRYPOINT` only if you intentionally want plain HTTP on `web`.
4. Make sure the external Docker network from `TRAEFIK_NETWORK` exists.

This only proxies the HTTP interface on port `8080`. RTMP and SRT remain direct host ports in this version.

## Notes

- If another stack already uses port `1935` or `6000`, change `RTMP_BIND_PORT` or `SRT_BIND_PORT` in `.env`.
- Upstream suggests `--security-opt seccomp=unconfined` only as a workaround when network sources cannot be reached. This stack does not enable that by default.
- AMD/VAAPI acceleration is intentionally deferred from this first version.
