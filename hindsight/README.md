# Hindsight

[Hindsight](https://github.com/vectorize-io/hindsight) provides long-term
memory for AI agents. This stack runs the API, MCP server, Control Plane UI,
and embedded PostgreSQL (pg0) in one container.

## Setup

The external `ai-tools` network is mandatory. Hindsight uses it to reach a
same-network `llama-swap` instance and to accept connections from services such
as Hermes without publishing the API beyond the Docker host.

```shell
docker network create ai-tools
cp .env.dist .env
nano -w .env
mkdir -p data
sudo chown -R 1000:1000 data
docker compose up -d
```

Generate different values for `HINDSIGHT_API_KEY` and
`HINDSIGHT_CP_ACCESS_KEY` before starting the stack:

```shell
openssl rand -hex 32
```

The upstream image runs as UID/GID 1000. The bind-mounted `data` directory
must be writable by that user or embedded pg0 will refuse to start.

## Endpoints

The default local endpoints are:

| Purpose | URL |
|---|---|
| REST API and documentation | `http://127.0.0.1:8417` |
| MCP, per bank | `http://127.0.0.1:8417/mcp/<bank_id>/` |
| Control Plane UI | `http://127.0.0.1:8418` |
| Same-network API | `http://hindsight:8888` |

REST and MCP clients authenticate with `HINDSIGHT_API_KEY` as a Bearer token.
The browser UI additionally prompts for `HINDSIGHT_CP_ACCESS_KEY`.

## Model provider

The tracked template defaults to the OpenAI-compatible endpoint exposed by the
repository's `llama-swap` stack on `ai-tools`:

```text
http://llama-swap:8080/v1
model: gemma-4-e4b-noreason
```

The model alias must exist in the deployed `llama-swap` configuration. Strict
schema output is enabled because it improves structured extraction with small
self-hosted models.

For a cheap hosted alternative, comment the active llama-swap variables in
`.env` and uncomment the native MiniMax example using `MiniMax-M3`. Do not set a
base URL for the native MiniMax provider; it uses the global API endpoint.
See the [supported models and providers](https://hindsight.vectorize.io/developer/models).

## Traefik

Set `COMPOSE_VARIANT=traefik`, configure `TRAEFIK_HOST`, and create the
external `traefik` network to expose Hindsight on the LAN. See the common
[Traefik usage guide](../_docs/traefik.md) and
[network setup](../_docs/traefik_network.md).

A single hostname serves both components without a custom image build:

- `/v1`, `/mcp`, `/docs`, `/openapi.json`, `/health`, and `/metrics` route to
  the API on port 8888.
- All remaining paths, including `/`, route to the Control Plane on port 9999.

The API router has a higher priority than the UI catch-all. Both use the shared
`websecure` entrypoint and `default-access@file` policy by default; no
router-level TLS settings override the entrypoint configuration.

With `TRAEFIK_HOST=hindsight.example.com`, use:

```text
API: https://hindsight.example.com
MCP: https://hindsight.example.com/mcp/<bank_id>/
UI:  https://hindsight.example.com/
```

The access-policy middleware is an additional layer in front of Hindsight's
own Bearer-token authentication. It must allow the authentication method used
by non-browser API and MCP clients.

## Hermes

Hermes has a native Hindsight provider; do not install the deprecated
standalone plugin. Run the setup wizard and select `hindsight`:

```shell
hermes memory setup
hermes memory status
```

For Hermes running on the same VPS Docker network, configure
`HINDSIGHT_API_URL=http://hindsight:8888` and set `HINDSIGHT_API_KEY` to this
stack's API key. The resulting `~/.hermes/hindsight/config.json` should retain
these integration settings:

```json
{
  "mode": "cloud",
  "api_url": "http://hindsight:8888",
  "api_key": "replace-with-hindsight-api-key",
  "bank_id": "hermes",
  "memory_mode": "hybrid",
  "autoRecall": true,
  "autoRetain": true,
  "recallBudget": "mid"
}
```

Here `cloud` means connecting to a remote Hindsight API; the URL can point to
this self-hosted container. See the
[Hindsight Hermes integration](https://hindsight.vectorize.io/sdks/integrations/hermes).

## Claude Code, Codex, and OpenCode

Use Hindsight's unified coding-agents package instead of the superseded
per-agent plugins. Install all three against the LAN endpoint:

```shell
npx @vectorize-io/hindsight-coding-agents install \
  claude-code codex opencode \
  --server self-hosted \
  --api-url https://hindsight.example.com \
  --api-token replace-with-hindsight-api-key
```

The installer stores the shared configuration in
`~/.hindsight/coding-agent.json`. Its default bank template is
`coding-agent::{gitProject}`, so Claude Code, Codex, and OpenCode share one
memory bank per repository, including linked worktrees. The integration seeds
Git history and a codebase survey, recalls knowledge at session start, and
retains sessions automatically; its pipeline replaces the Hermes-specific
`memory_mode`, `autoRecall`, `autoRetain`, and `recallBudget` controls.

Integration details:

- [Hindsight coding agents](https://hindsight.vectorize.io/sdks/integrations/coding-agents)
- [Claude Code MCP](https://code.claude.com/docs/en/mcp)
- [Codex MCP](https://learn.chatgpt.com/docs/extend/mcp)
- [OpenCode plugins](https://opencode.ai/docs/plugins/)

## Storage and resources

Embedded pg0 data is persisted under `HOST_DATA_DIR` (default `./data`). Back
up this directory together with `.env`, and allow the 30-second Compose stop
grace period so PostgreSQL can flush its WAL cleanly.

`SHM_SIZE` defaults to `1g`, a practical default for the embedded PostgreSQL
deployment. The full Hindsight image also loads local embedding and reranking
models; budget roughly 2 GiB for the API plus 1 GiB or more for the database.
Upstream recommends an external PostgreSQL service for larger or
production-critical deployments.

## References

- [Hindsight documentation](https://hindsight.vectorize.io)
- [Docker installation](https://hindsight.vectorize.io/developer/installation)
- [Configuration reference](https://hindsight.vectorize.io/developer/configuration)
- [MCP server](https://hindsight.vectorize.io/developer/mcp-server)
