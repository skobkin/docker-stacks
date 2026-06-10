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

Run Hermes commands inside the container. The four commands below cover the
common first-time setup and day-to-day health checks.

```shell
# Run the Nous Portal onboarding wizard: OAuth login, default-model selection,
# and an opt-in to the Nous Tool Gateway. Equivalent to the bare `hermes portal`
# command but launched through the interactive `setup` wizard.
docker compose exec hermes hermes setup --portal

# Interactive configuration wizard for messaging platforms (Telegram, Discord,
# Slack, etc.) — registers platform credentials, allowlists, and home channels.
docker compose exec hermes hermes gateway setup

# Show agent, auth, and platform status (provider configured, gateway running,
# which platforms are connected, etc.).
docker compose exec hermes hermes status

# Tail the agent / gateway / error logs (equivalent to `hermes logs -f`).
docker compose exec hermes hermes logs --follow
```

Profiles let you run several independent Hermes instances with isolated
`~/.hermes/` directories. The `default` profile is the one this stack
manages; the other commands target a named profile via `-p <name>`.

```shell
# Create a new named profile (e.g. for a separate gateway / memory / skill set).
docker compose exec hermes hermes profile create <name>

# Show / select the sticky default profile (lists existing profiles).
docker compose exec hermes hermes profile

# Start the gateway as a managed service for the given profile.
docker compose exec hermes hermes -p <name> gateway start

# Stop the gateway service for the given profile.
docker compose exec hermes hermes -p <name> gateway stop

# Restart the gateway service for the given profile.
docker compose exec hermes hermes -p <name> gateway restart

# Show whether the gateway service for the given profile is running.
docker compose exec hermes hermes -p <name> gateway status

# Delete a named profile and its isolated `~/.hermes/profiles/<name>/` tree.
docker compose exec hermes hermes profile delete <name>
```

Pairing controls who can DM your bot on a connected platform. Pending codes
appear in `pairing list`; approve them to grant access, revoke to remove an
existing user, or `clear-pending` to drop the queue.

```shell
# List pending DM pairing codes across all connected platforms.
docker compose exec hermes hermes pairing list

# Approve a pending code: the user can then DM the bot on that platform.
docker compose exec hermes hermes pairing approve <platform> <code>

# Revoke a previously approved user (by platform-specific user id).
docker compose exec hermes hermes pairing revoke <platform> <user>

# Drop all pending codes without approving any of them.
docker compose exec hermes hermes pairing clear-pending
```

The subscription proxy lets any local client present a bearer token to Hermes,
which attaches your real provider credential upstream. It has no auth of its
own, so this stack intentionally does not expose it through Traefik — start
it bound to the loopback address only.

```shell
# Show Nous Portal status (alias of `hermes auth add nous --type oauth`).
docker compose exec hermes hermes portal

# Start the OpenAI-compatible proxy on the loopback (no auth — bind 127.0.0.1).
docker compose exec hermes hermes proxy start --host 127.0.0.1 --port 8645

# Show whether the proxy is running and on which port.
docker compose exec hermes hermes proxy status

# List upstream providers currently wired through the proxy.
docker compose exec hermes hermes proxy providers
```

The subscription proxy accepts any bearer token and attaches your real provider credential upstream. This stack intentionally does not expose it through Traefik.

## Notes

The default `IMAGE_TAG=main` tracks upstream's rolling Docker image. For stricter deployments, pin a verified immutable `sha-*` image tag in `.env`.

Do not mount the host Docker socket into this container. Keep platform allowlists explicit, keep `GATEWAY_ALLOW_ALL_USERS=false`, and do not enable `HERMES_YOLO_MODE` for normal deployments.
