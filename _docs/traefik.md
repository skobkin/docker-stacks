# Common Traefik Usage

Use this pattern for stacks in this repository that provide optional Docker-internal HTTP exposure through the shared Traefik stack.

Most of these stacks:

- keep their normal localhost port binding even when Traefik is enabled
- switch the optional Traefik integration on with `COMPOSE_VARIANT=traefik`
- attach to the external Docker network from `TRAEFIK_NETWORK`
- use one host-based router via `TRAEFIK_HOST`
- default to Traefik's shared `websecure` entrypoint unless `TRAEFIK_ENTRYPOINT` is overridden
- use the shared `grpcsecure` entrypoint for gRPC-over-HTTPS routers when a stack exposes gRPC through Traefik

## Typical Setup

1. Create the shared external Docker network if you have not done that yet. See [traefik_network.md](./traefik_network.md).
2. Set `COMPOSE_VARIANT=traefik` in the stack `.env`.
3. Set `TRAEFIK_HOST` to the public hostname that Traefik should route to that stack.
4. Leave `TRAEFIK_ENTRYPOINT=websecure` unless you intentionally want another entrypoint such as `web`.
5. Start or recreate the stack with `docker compose up -d`.

## Common Variables

- `COMPOSE_VARIANT=traefik`: enables the Traefik-specific compose feature set
- `TRAEFIK_NETWORK=traefik`: external Docker network shared with the Traefik stack
- `TRAEFIK_HOST=app.example.com`: hostname used in the Traefik router rule
- `TRAEFIK_ENTRYPOINT=websecure`: Traefik entrypoint for the router
- `TRAEFIK_SERVICE_PORT=<container-http-port>`: internal container port that Traefik should forward to when the stack exposes this knob
- `TRAEFIK_GRPC_ENTRYPOINT=grpcsecure`: shared Traefik entrypoint for gRPC-over-HTTPS routers
- `TRAEFIK_GRPC_SERVICE_PORT=<container-grpc-port>`: internal container gRPC port that Traefik should forward to when the stack exposes this knob

## Notes

- With the shared `websecure` entrypoint, stacks usually rely on Traefik's entrypoint-level TLS and certificate resolver defaults instead of setting router-level TLS labels.
- The shared `websecure` entrypoint enables HTTP/3 by default when the Traefik stack can receive UDP traffic on its HTTPS UDP bind port.
- The shared `grpcsecure` entrypoint listens on port `9443` by default. Multiple gRPC services can reuse it with different `Host(...)` rules.
- WebSocket upgrades usually work through the same HTTP router without extra Traefik switches, as long as the backend and any applied middlewares do not break `Upgrade` handling.
- If a stack README has extra Traefik notes, those are stack-specific requirements and override this generic pattern.

## Static File Catalogs

The Traefik stack mounts `STATIC_FILES_PATH` read-only at `/srv/static`.

For multiple public file catalogs, keep one live file-provider config per hostname under `traefik/config/dynamic/*.yml` and point the `statiq` middleware root at a subdirectory such as `/srv/static/f.example.com` or `/srv/static/i.example.com`.

Use `traefik/config/dynamic/static-files.yml.dist` as the starting example for each catalog router.
