# Hermes Agent

Hermes Agent runs as a persistent gateway with the supervised web dashboard enabled in the same container. The stack mounts `./data` to `/opt/data`, where Hermes stores profiles, `config.yaml`, secrets, auth state, sessions, and logs.

## Networks

The default variant joins the external [`ai-tools`](../_docs/ai_tools_network.md) Docker network so Hermes can reach local model routers such as `llama-swap` and `ollama` by container name.

Create required and optional networks before starting matching variants:

```shell
docker network create ai-tools
docker network create proxy
docker network create traefik
```

The optional [`proxy`](../_docs/proxy_network.md) network is intended for outbound proxy containers such as `mihomo`. The optional [`traefik`](../_docs/traefik_network.md) network is used only by Traefik variants; see the shared [Traefik usage guide](../_docs/traefik.md) for router, entrypoint, and access-policy behavior.

## Setup

```shell
cp .env.dist .env
nano -w .env
docker compose up -d
```

Before first start, edit dashboard credentials in `.env`. This Compose template requires `HERMES_DASHBOARD_BASIC_AUTH_USERNAME`, `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH`, and a stable `HERMES_DASHBOARD_BASIC_AUTH_SECRET`.

The default dashboard URL is `http://127.0.0.1:8410`.

## Variants

Set `COMPOSE_VARIANT` in `.env`:

| Variant             | Behavior                                                                   |
|---------------------|----------------------------------------------------------------------------|
| `default`           | Dashboard enabled, API disabled, joins `ai-tools` only                     |
| `proxy`             | Adds the external `proxy` network                                          |
| `api`               | Enables and publishes the OpenAI-compatible API server on `127.0.0.1:8642` |
| `api_proxy`         | Combines `api` and `proxy`                                                 |
| `traefik`           | Adds a Traefik router for the dashboard                                    |
| `traefik_proxy`     | Combines dashboard Traefik routing and `proxy`                             |
| `traefik_api`       | Adds Traefik routers for the dashboard and API server                      |
| `traefik_api_proxy` | Combines Traefik dashboard/API routing and `proxy`                         |

API variants require `API_SERVER_KEY`. Traefik API variants use `TRAEFIK_HOST` for the dashboard and `TRAEFIK_API_HOST` for the API server.

## Management

Run Hermes commands inside the container:

```shell
docker compose exec hermes hermes setup --portal
docker compose exec hermes hermes gateway setup
docker compose exec hermes hermes status
docker compose exec hermes hermes logs --follow
```

Profile commands:

```shell
docker compose exec hermes hermes profile create <name>
docker compose exec hermes hermes profile
docker compose exec hermes hermes -p <name> gateway start
docker compose exec hermes hermes -p <name> gateway stop
docker compose exec hermes hermes -p <name> gateway restart
docker compose exec hermes hermes -p <name> gateway status
docker compose exec hermes hermes profile delete <name>
```

Pairing commands:

```shell
docker compose exec hermes hermes pairing list
docker compose exec hermes hermes pairing approve <platform> <code>
docker compose exec hermes hermes pairing revoke <platform> <user>
docker compose exec hermes hermes pairing clear-pending
```

Subscription proxy commands:

```shell
docker compose exec hermes hermes portal
docker compose exec hermes hermes proxy start --host 127.0.0.1 --port 8645
docker compose exec hermes hermes proxy status
docker compose exec hermes hermes proxy providers
```

The subscription proxy accepts any bearer token and attaches your real provider credential upstream. This stack intentionally does not expose it through Traefik.

## Notes

The default `IMAGE_TAG=main` tracks upstream's rolling Docker image. For stricter deployments, pin a verified immutable `sha-*` image tag in `.env`.

Do not mount the host Docker socket into this container. Keep platform allowlists explicit, keep `GATEWAY_ALLOW_ALL_USERS=false`, and do not enable `HERMES_YOLO_MODE` for normal deployments.
