# OpenCloud

Self-hosted file sync and share platform from the original ownCloud team —
the successor of ownCloud Infinite Stack (oCIS). This stack runs the
all-in-one image: web frontend, built-in IdP and reverse proxy in a single
process, no external database. Optional full-text search (Apache Tika) and
the Collabora Online office suite are available as compose profiles.

- Website: [opencloud.eu](https://opencloud.eu)
- Documentation: [docs.opencloud.eu](https://docs.opencloud.eu/docs/admin/)
- Source: [github.com/opencloud-eu/opencloud](https://github.com/opencloud-eu/opencloud)
- Upstream compose examples: [github.com/opencloud-eu/opencloud-compose](https://github.com/opencloud-eu/opencloud-compose)
- Image: [hub.docker.com/r/opencloudeu/opencloud](https://hub.docker.com/r/opencloudeu/opencloud)

## Prerequisites

The container runs as UID/GID 1000 by default (see `HOST_USER`/`HOST_GROUP`
in `.env.dist`). Create the host directories and hand them to that user:

```shell
mkdir -p config data config/apps
sudo chown -R 1000:1000 config data config/apps
```

`config/` holds generated secrets and configuration, `data/` holds the stored
files, `config/apps/` is the drop-in for web extension apps.

## Quick start

```shell
cd opencloud
cp .env.dist .env
nano -w .env              # set OC_URL and INITIAL_ADMIN_PASSWORD
docker compose up -d
docker compose logs -f
```

Then open http://127.0.0.1:9200 (default `BIND_ADDRESS`/`BIND_PORT`) and log
in as `admin` with the `INITIAL_ADMIN_PASSWORD` value.

### First start semantics

- The entrypoint runs `opencloud init` on the first start, which generates
  the internal secrets into `config/` and creates the initial `admin`
  account from `INITIAL_ADMIN_PASSWORD`.
- `INITIAL_ADMIN_PASSWORD` is **only read on the first start** of a fresh
  `data/` directory. Later edits to `.env` are ignored — rotate the password
  via the web UI or the `opencloud idm` CLI. Keep the variable set anyway:
  the compose file requires it and the IdP fails without it.
- `OC_URL` bakes into generated links and tokens; set it correctly before
  the first start and keep it stable afterwards.

## Variants

| Variant    | Networking | Traefik | Use when                          |
|------------|------------|---------|-----------------------------------|
| `default`  | bridge     | —       | plain localhost-bound usage       |
| `traefik`  | bridge     | yes     | instance behind Traefik           |

Switch variants by setting `COMPOSE_VARIANT` in `.env` and running
`docker compose up -d` again. Both variants publish
`${BIND_ADDRESS}:${BIND_PORT}` (default `127.0.0.1:9200`); the localhost
binding stays enabled in the `traefik` variant as well.

Set `OC_URL` to match the variant:

- `default`: `http://127.0.0.1:9200` — fine for testing, but share links and
  desktop/mobile clients only work from the host itself.
- `traefik`: `https://<TRAEFIK_HOST>` — required for anything beyond local
  testing (clients, shares, apps).

## Optional services (profiles)

Unlike the exposure variant, optional containers are enabled with Compose
profiles, independently of `COMPOSE_VARIANT` — combine them freely:

```dotenv
COMPOSE_PROFILES=fulltext,collabora
```

| Profile      | Adds                                            | Extra `.env` block to uncomment |
|--------------|-------------------------------------------------|---------------------------------|
| `fulltext`   | Apache Tika content extractor, full-text search | "full-text search" block        |
| `collabora`  | Collabora Online + WOPI proof-key sidecar       | "Collabora Online" block        |

Notes:

- `opencloud` starts before `tika` and picks the extractor up once Tika is
  reachable; there is no hard dependency between the containers.
- The `collabora` block must be uncommented together with the profile — in
  particular `OC_ADD_RUN_SERVICES` needs `collaboration`, or the WOPI
  service inside the main container will not start.
- Collabora is reached by browsers directly, so it needs its own public
  DNS name (`COLLABORA_HOST`) routed via Traefik and, realistically, the
  `traefik` variant. Its container requires elevated privileges
  (`SYS_ADMIN`, `seccomp`/`apparmor` unconfined) as upstream requires.
- Profiles are a Docker Compose feature: with `COMPOSE_PROFILES` unset, the
  extra containers are not created at all.

## Traefik

The `traefik` variant requires:

```shell
TRAEFIK_HOST=opencloud.example.com
OC_URL=https://opencloud.example.com
```

TLS is terminated by Traefik (the container itself serves plain HTTP on the
`websecure` entrypoint behind the shared proxy). See
[_docs/traefik.md](../_docs/traefik.md) and
[_docs/traefik_network.md](../_docs/traefik_network.md) for the repo-wide
Traefik setup.

## Data and backup

All state lives in `config/` (secrets, IdP data, configuration) and `data/`
(user files). Stop the stack before copying so the backup is consistent:

```shell
docker compose stop
cp -a config data /path/to/backup/
docker compose start
```

## Possible future additions

- CSP / app-registry / banned-password file mounts
  (`csp.yaml`, `apps.yaml`, `banned-password-list.txt`) as in the upstream
  compose examples.
- Antivirus via `OC_ADD_RUN_SERVICES=antivirus`.
- Metrics endpoint (port 9205).

## Docs

- Upstream repository: [github.com/opencloud-eu/opencloud](https://github.com/opencloud-eu/opencloud)
- Upstream compose examples: [github.com/opencloud-eu/opencloud-compose](https://github.com/opencloud-eu/opencloud-compose)
- Image: [hub.docker.com/r/opencloudeu/opencloud](https://hub.docker.com/r/opencloudeu/opencloud)
- Port usage: [../PORTS.md](../PORTS.md)
