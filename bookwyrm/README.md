# Bookwyrm

Self-hosted federated book social network — Goodreads-style reading logs, reviews,
and discussion that speaks ActivityPub and can interoperate with other Bookwyrm
and Mastodon instances.

- Project site: <https://joinbookwyrm.com>
- Source / docs: <https://github.com/bookwyrm-social/bookwyrm>
- Image: <https://hub.docker.com/r/bookwyrm/bookwyrm>

This stack runs the official `bookwyrm/bookwyrm` image directly (no source build).

## Quick start

```sh
cp .env.dist .env
$EDITOR .env   # set SECRET_KEY, POSTGRES_PASSWORD, REDIS_*_PASSWORD, FLOWER_PASSWORD, DOMAIN, TRAEFIK_HOST, EMAIL_*
docker compose up -d
```

The `web` container's entrypoint runs `migrate`, `initdb`, `compile_themes`, and
`collectstatic` automatically on first start. Register the first admin user from
the web UI — Bookwyrm has no CLI for this.

## Networking

The stack defaults to `COMPOSE_VARIANT=traefik` so a fresh deploy lands on the
shared Traefik path:

- A central reverse proxy terminates TLS and forwards to this stack on the
  shared `traefik` Docker network.
- Traefik applies the `default-access@file` middleware (Anubis ForwardAuth) so
  the central Anubis instance gates anonymous traffic.
- A small nginx sidecar (`bookwyrm-static`) serves `/static/` and `/images/`
  directly. Path-based routing in `compose.static-features.yml` uses priority
  `1` for static files and priority `0` for the web catch-all, so static
  requests go to nginx and everything else to gunicorn.
- `flower` (Celery monitor) is **not** published to Traefik. It is bound to
  `127.0.0.1:${FLOWER_BIND_PORT:-8440}` and must be reached over an SSH tunnel:
  `ssh -L 8440:127.0.0.1:8440 <host>`, then open <http://localhost:8440/flower>.

The `web` port `8430` is also bound to `127.0.0.1` for direct testing and for
running `docker compose run --rm web manage.py ...`.

For ActivityPub streaming responses, add the `long-lived@file` transport to the
`bookwyrm-web` service on the central Traefik side (see
`traefik/config/dynamic/shared.yml.dist`):

```yaml
traefik.http.services.bookwyrm-web.loadbalancer.serverstransport: long-lived@file
```

## `databases` variant

If you already run a central Postgres + two Redis instances on the shared
`databases` Docker network ([_docs/databases_network.md](../_docs/databases_network.md)),
set `COMPOSE_VARIANT=databases` (or `COMPOSE_VARIANT=traefik_databases` to keep
Traefik routing) and point the database vars at the central hosts:

```dotenv
COMPOSE_VARIANT=traefik_databases
POSTGRES_HOST=postgres
REDIS_BROKER_HOST=redis-broker
REDIS_ACTIVITY_HOST=redis-activity
```

The `db`, `redis_broker`, and `redis_activity` services are gated by
`profiles: [local]`, so they are skipped in the `databases` /
`traefik_databases` variants and the stack connects to the central services
instead.

## Static and media

User-uploaded covers and avatars land in `./media/` (bind-mounted to
`/app/images/` inside the containers). The `static` service caches fingerprinted
assets from `./static/` (bind-mounted to `/app/static/`) with a long
`Cache-Control` header.

The image allow-list in `static/nginx-static.conf` matches the upstream nginx
config: `bmp|ico|jpg|jpeg|png|svg|tif|tiff|webp`.

## SMTP

All `EMAIL_*` variables in `.env` are required for the user-registration and
password-reset flows. Uncomment the relevant lines in `.env.dist` and set them
before the first user signs up.

## Updating

```sh
docker compose pull web celery_worker celery_beat flower
docker compose up -d
```

The `web` entrypoint re-runs migrations and `collectstatic` idempotently on
restart. Pin `IMAGE_TAG` in `.env` for production — `latest` is fine for a
home server but is not reproducible.

## Backups

`./pgdata/`, `./backups/`, `./media/`, `./exports/`, and the two `./redis_*/`
directories are bind-mounts under the stack directory. Back them up with your
host's normal backup tooling. The Postgres container writes `pg_dump` archives
to `./backups/` if you run them with the `BACKUPS_PATH` bind mount.
