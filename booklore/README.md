# BookLore

Self-hosted book collection manager with reader and sync.

## Quick start

BookLore UI is available at `http://127.0.0.1:6060`. First-run admin credentials are `admin@admin.com` / `admin`.

Requires an external MariaDB or MySQL database. See `.env.dist` for configuration variables and set `DB_PASSWORD` before deploying.

## Databases network

BookLore connects to an external database via the shared `databases` network documented in [_docs/databases_network.md](../_docs/databases_network.md). The `databases` network is always attached to the BookLore container.

## Traefik integration

Enable Traefik routing by setting `COMPOSE_VARIANT=traefik` in `.env`.

Check [_docs/traefik.md](../_docs/traefik.md) for more details.

## Update

```sh
docker compose pull
docker compose up -d booklore
```
