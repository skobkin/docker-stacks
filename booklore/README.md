# BookLore

Self-hosted book collection manager with reader and sync.

## Quick start

BookLore UI is available at `http://127.0.0.1:6060`. First-run admin credentials are `admin@admin.com` / `admin`.

## Traefik integration

Enable Traefik routing by setting `COMPOSE_VARIANT=traefik` in `.env`. BookLore exposes a private HTTP router for LAN access. For public HTTPS access as well, set `COMPOSE_VARIANT=traefik_dual` and set `TRAEFIK_HOST_PUBLIC` to your domain.

| Router             | Entrypoint                                          | Hostname                                         | TLS | Variant        |
|--------------------|-----------------------------------------------------|--------------------------------------------------|-----|----------------|
| `booklore-private` | `TRAEFIK_ENTRYPOINTS_PRIVATE` (default: `web`)      | `TRAEFIK_HOST_PRIVATE` (default: `booklore.lan`) | No  | `traefik`      |
| `booklore-public`  | `TRAEFIK_ENTRYPOINTS_PUBLIC` (default: `websecure`) | `TRAEFIK_HOST_PUBLIC` (required)                 | Yes | `traefik_dual` |

## Update

```sh
docker compose pull
docker compose up -d booklore
```
