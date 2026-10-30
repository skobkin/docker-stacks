# Bifrost

Single-container LLM gateway: one endpoint for cloud providers (Anthropic, OpenAI, Google, and others) and local inference (Ollama, llama.cpp, vLLM, or any OpenAI-compatible server). Exposes an OpenAI-compatible API at `/v1`, an Anthropic-compatible API at `/anthropic`, an MCP gateway at `/mcp`, and an admin Web UI — all on container port 8080. Configuration lives in a SQLite database under `data/`.

- Website: https://www.getbifrost.ai
- GitHub: https://github.com/maximhq/bifrost
- Documentation: https://docs.getbifrost.ai
- Container/storage contract: https://docs.getbifrost.ai/deployment-guides/runtime-contract
- Repo issue: [#400](https://git.skobk.in/skobkin/docker-stacks/issues/400)

The stack joins the external `ai-tools` network, so repo-hosted inference (e.g. [ollama](../ollama/), [llama-swap](../llama-swap/)) is reachable by container name.

## Security warning

A fresh Bifrost install serves an **unauthenticated admin dashboard** until the first admin account is created. Anyone who can reach the port or hostname can change configuration and read the Web UI.

- The default Traefik variant keeps the dashboard behind your Traefik access policy (`default-access@file`); check what that middleware does in your Traefik config before exposing the hostname anywhere broad.
- Complete the [first admin setup](#first-admin) immediately after the first start, before telling anyone the URL.
- The non-Traefik variant binds to `127.0.0.1` only — do not change `BIND_ADDRESS` to a LAN address before the first admin exists.

## Setup

1. Copy the template and fill in the secrets:

   ```shell
   cp .env.dist .env
   # Encryption key (must stay stable forever):
   sed -i "s|^BIFROST_ENCRYPTION_KEY=.*|BIFROST_ENCRYPTION_KEY=$(openssl rand -base64 32)|" .env
   # One-time setup token (remove the line after the first admin exists):
   sed -i "s|^BIFROST_SETUP_TOKEN=.*|BIFROST_SETUP_TOKEN=$(openssl rand -hex 32)|" .env
   ```

2. Create the data directory with correct ownership. The image runs as UID/GID 1000, and the bind mount shadows the image's own `/app/data` — Docker will not fix up ownership:

   ```shell
   sudo install -d -o 1000 -g 1000 data
   ```

3. Start the stack. The default variant publishes through Traefik; set `TRAEFIK_HOST` in `.env` first (see [Traefik](../_docs/traefik.md), [traefik network](../_docs/traefik_network.md)).

   ```shell
   docker compose up -d
   ```

   Without Traefik, switch to the localhost-bound variant — the UI is then at `http://127.0.0.1:8422`:

   ```shell
   echo 'COMPOSE_VARIANT=default' >> .env
   docker compose up -d
   ```

   Both variants need the external `ai-tools` network ([guide](../_docs/ai_tools_network.md)).

### Declarative config seed

Bifrost can seed its database from `/app/data/config.json` on startup. The compose file always declares the mount, but by default **both sides resolve to `/dev/null`** — a no-op mount, so no seed file exists and the Web UI/database config model stays fully in charge. Once a seed is mounted at `/app/data/config.json`, the file must exist and hold valid JSON: an empty or missing file fails startup, which is why the inactive default must not put `/dev/null` on the config path itself.

To activate the seed, copy the template, add settings, and set both mount variables in `.env`:

```shell
cp config/config.json.dist config/config.json
```

```dotenv
CONFIG_FILE=./config/config.json
CONFIG_FILE_MAPPED=/app/data/config.json
```

Example seed content — note secrets are only ever referenced as `env.VARIABLE_NAME`, never written literally:

```json
{
  "$schema": "https://www.getbifrost.ai/schema",
  "encryption_key": "env.BIFROST_ENCRYPTION_KEY",
  "setup_token": "env.BIFROST_SETUP_TOKEN",
  "config_store": { "source_of_truth": "split" },
  "providers": {
    "openai": {
      "keys": [{ "name": "openai", "value": "env.OPENAI_API_KEY", "models": ["*"], "weight": 1.0 }]
    },
    "anthropic": {
      "keys": [{ "name": "anthropic", "value": "env.ANTHROPIC_API_KEY", "models": ["*"], "weight": 1.0 }]
    }
  }
}
```

In the default `split` mode the Web UI stays authoritative for rows the file does not change; rows changed in the file are re-applied on restart, so the file remains the place to keep versioned provider defaults. Full reference: https://docs.getbifrost.ai/deployment-guides/config-json.

## First admin

Open the Web UI (through Traefik at your `TRAEFIK_HOST`, or `http://127.0.0.1:8422` on the default variant) and create the admin account when asked for the setup token — use `BIFROST_SETUP_TOKEN` from `.env`.

The token is only read until the first admin exists. Afterwards delete the `BIFROST_SETUP_TOKEN` line from `.env` and `docker compose up -d` to drop it from the container environment. See https://docs.getbifrost.ai/quickstart/gateway/setting-up-auth.

## Providers and local inference

Register providers in the Web UI (Providers → add provider, paste the API key). Keys are stored encrypted in the SQLite database using `BIFROST_ENCRYPTION_KEY`.

Local inference resolves URLs **from inside the bifrost container** — `localhost` there means the gateway itself, not your host or LAN machine:

- Containers on the shared `ai-tools` network: use container names. [Ollama](../ollama/) is registered with server URL `http://ollama:11434`; [llama-swap](../llama-swap/) or any other OpenAI-compatible server is registered as a custom provider with base URL `http://llama-swap:8080/v1`.
- Inference on another machine (LAN/VPN): use its IP or hostname, e.g. `http://192.168.1.50:11434`.
- The Docker host itself: `localhost` does not work from the container — use the host's LAN/VPN address, not `http://localhost:11434`.

## Client authentication

Clients authenticate with **virtual keys** created in the Web UI (Governance → Virtual Keys). A key looks like `vk_...`, can be scoped to specific providers/models/budgets, and is sent as a normal bearer token:

```text
Authorization: Bearer vk_xxxxxxxxxxxxxxxx
```

## Using the gateway

- OpenAI clients — point `base_url` at the gateway root plus `/v1`:
  `http://127.0.0.1:8422/v1` (default variant) or `https://<TRAEFIK_HOST>/v1` (Traefik).
- Anthropic SDK clients — same host plus `/anthropic`:
  `http://127.0.0.1:8422/anthropic` or `https://<TRAEFIK_HOST>/anthropic`.
- Claude Code — route the CLI through the gateway:

  ```shell
  export ANTHROPIC_BASE_URL=http://127.0.0.1:8422/anthropic
  export ANTHROPIC_AUTH_TOKEN=vk_xxxxxxxxxxxxxxxx
  ```

  Non-Anthropic models can be pinned with `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, and `ANTHROPIC_DEFAULT_HAIKU_MODEL`; expect degraded behavior where Claude-specific features are involved. Full details: https://docs.getbifrost.ai/cli-agents/claude-code.

## MCP gateway

Bifrost proxies registered MCP servers through one governed endpoint at `/mcp`. With the default header auth mode, authenticate with a virtual key as `Authorization: Bearer vk_...` (or `x-bf-vk: vk_...`). An OAuth 2.1 browser sign-in flow is available by switching the MCP auth mode to `both`/`oauth` in the Web UI.

Register it with Claude Code:

```shell
claude mcp add --transport http bifrost https://<TRAEFIK_HOST>/mcp \
  --header "Authorization: Bearer replace-with-virtual-key"
```

General client setup: [MCP client guide](../_docs/mcp.md). Gateway auth details: https://docs.getbifrost.ai/mcp/gateway-auth.

## Streaming through Traefik

LLM responses stream as SSE and can sit idle for minutes before the first bytes arrive. The Traefik variant attaches the shared `long-lived@file` serversTransport (no response-header timeout, long idle timeout — defined in `traefik/config/dynamic/shared.yml.dist`) so long streams are not cut off by the proxy. WebSocket upgrades work through the same router without extra settings.

## Logging and privacy

Bifrost writes request logs (prompts, model calls, token usage) into the SQLite database under `data/`. If you do not want request content retained, disable request logging or set a short retention in the Web UI. Container stdout logging defaults to JSON at `info` level — override with `LOG_STYLE=console` and `LOG_LEVEL` in `.env`.

## Backup and restore

Stop the container, then back up:

- `data/` — SQLite database (config store, provider keys, request logs);
- `.env` — **must** be backed up together with `data/`: without the original `BIFROST_ENCRYPTION_KEY`, everything encrypted in the database becomes unreadable.

Restore by putting both back and starting the stack.

Database migrations run on every startup and are **not** reversed by rolling the image back to an older version — restore a `data/` backup instead of downgrading.

## Upgrading

```shell
docker compose pull && docker compose up -d
```

The default `IMAGE_TAG=latest` lets watchtower apply updates automatically, but since migrations are one-way, back up `data/` before upgrading and pin an exact tag (`IMAGE_TAG=vX.Y.Z`) if you prefer manual control.

## Out of scope

PostgreSQL as the config store and ClickHouse/Prometheus/Grafana observability exports are supported upstream but intentionally not wired up here. See https://docs.getbifrost.ai if you need them.

## References

- Runtime contract (ports, storage, health): https://docs.getbifrost.ai/deployment-guides/runtime-contract
- Config file reference: https://docs.getbifrost.ai/deployment-guides/config-json
- Docker tuning (GOMEMLIMIT/GOGC): https://docs.getbifrost.ai/deployment-guides/docker-tuning
- Virtual keys: https://docs.getbifrost.ai/quickstart/gateway/setting-up-auth
