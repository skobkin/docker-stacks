# Common Traefik Usage

Use this pattern for stacks in this repository that provide optional Docker-internal HTTP exposure through the shared Traefik stack.

Most of these stacks:

- keep their normal localhost port binding even when Traefik is enabled
- switch the optional Traefik integration on with `COMPOSE_VARIANT=traefik`
- attach to the external Docker network from `TRAEFIK_NETWORK`
- use one host-based router via `TRAEFIK_HOST`
- default to Traefik's shared `websecure` entrypoint unless `TRAEFIK_ENTRYPOINT` is overridden
- apply `TRAEFIK_ACCESS_POLICY`, defaulting to `default-access@file`, before stack-specific router middlewares
- use the shared `grpcsecure` entrypoint for gRPC-over-HTTPS routers when a stack exposes gRPC through Traefik

## Typical Setup

1. Create the shared external Docker network if you have not done that yet. See [traefik_network.md](./traefik_network.md).
2. Set `COMPOSE_VARIANT=traefik` in the stack `.env`.
3. Set `TRAEFIK_HOST` to the public hostname that Traefik should route to that stack.
4. Leave `TRAEFIK_ENTRYPOINT=websecure` unless you intentionally want another entrypoint such as `web`.
5. Review `traefik/config/dynamic/default-access.yml` in the Traefik stack and uncomment exactly one private or public `default-access` definition.
6. Start or recreate the stack with `docker compose up -d`.

## Common Variables

- `COMPOSE_VARIANT=traefik`: enables the Traefik-specific compose feature set
- `TRAEFIK_NETWORK=traefik`: external Docker network shared with the Traefik stack
- `TRAEFIK_HOST=app.example.com`: hostname used in the Traefik router rule
- `TRAEFIK_ENTRYPOINT=websecure`: Traefik entrypoint for the router
- `TRAEFIK_ACCESS_POLICY=default-access@file`: middleware applied before other router middlewares; stacks default to this when unset
- `TRAEFIK_SERVICE_PORT=<container-http-port>`: internal container port that Traefik should forward to when the stack exposes this knob
- `TRAEFIK_GRPC_ENTRYPOINT=grpcsecure`: shared Traefik entrypoint for gRPC-over-HTTPS routers
- `TRAEFIK_GRPC_SERVICE_PORT=<container-grpc-port>`: internal container gRPC port that Traefik should forward to when the stack exposes this knob

## Access Policy

Every Traefik-enabled application stack router uses `${TRAEFIK_ACCESS_POLICY:-default-access@file}` as its first middleware. The Traefik dashboard router is configured in the Traefik stack itself and uses `TRAEFIK_DASHBOARD_MIDDLEWARES` instead.

`default-access@file` is defined locally in the Traefik file-provider config, so operators choose whether the default behavior is private or public by editing `traefik/config/dynamic/default-access.yml`.

For a single stack that should bypass the default private policy, copy `traefik/config/dynamic/public-access.yml.dist` to `traefik/config/dynamic/public-access.yml`, then set this in that stack's `.env`:

```dotenv
TRAEFIK_ACCESS_POLICY=public-access@file
```

Use this override intentionally. It affects all Traefik routers in that stack, including secondary routers such as sockets, federation, or gRPC routes.

## Unknown Host Redirect

By default, Traefik returns its normal not-found response when a request host does not match any Docker-label router or file-provider router.

To redirect unmatched hostnames to a canonical URL, copy `traefik/config/dynamic/unknown-host-redirect.yml.dist` to `traefik/config/dynamic/unknown-host-redirect.yml`, then edit the live file and replace `https://traefik.example.com/` with the target URL.

The example defines a low-priority catch-all router on `web` and `websecure`. More specific stack routers keep winning; the catch-all only handles requests left unmatched by other routers.

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
