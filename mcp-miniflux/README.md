# Miniflux MCP

[Miniflux MCP](https://git.skobk.in/skobkin/miniflux-mcp-hardened) exposes feeds, entries, categories, users, API keys, and discovery to MCP clients over streamable HTTP. The server speaks to Miniflux via its Go client, so every connected MCP client shares the same Miniflux identity and its permissions.

## Setup

```shell
cp .env.dist .env
nano -w .env
docker compose up -d
```

Set `MINIFLUX_URL` to the base URL of the Miniflux instance. Default mode is API key auth — generate a key in Miniflux under Settings → API Keys ([docs](https://miniflux.app/docs/api.html#authentication)) and paste it into `MINIFLUX_API_KEY`. The default MCP client URL is:

```text
http://127.0.0.1:8417/mcp
```

The health endpoint is `/healthz`. The port is bound to localhost by default. Change `BIND_ADDR` only when the endpoint is protected by an appropriate network or access-control layer.

This service joins the external [`ai-tools`](../_docs/ai_tools_network.md) Docker network so MCP clients and other AI services can reach it as `mcp-miniflux:8080`. Create the network before starting the stack:

```shell
docker network create ai-tools
```

## Authentication

Two pieces of authentication to think about.

**MCP server ↔ client.** The streamable HTTP endpoint at `/mcp` is protected by the static Bearer token in `MCP_AUTH_TOKEN`. Every MCP client must send it on every request as `Authorization: Bearer <value>`. The unauthenticated `/healthz` endpoint is exposed on the same port for liveness probes.

**MCP server ↔ Miniflux.** Selected by what's set in `.env`:

- `MINIFLUX_API_KEY` (default): the API key from Miniflux's Settings → API Keys page.
- `MINIFLUX_USERNAME` + `MINIFLUX_PASSWORD`: basic-auth fallback. Comment out `MINIFLUX_API_KEY` and uncomment both lines to switch.

The upstream rejects both modes being set at once. The server also calls Miniflux's `Healthcheck` and `Me` on startup and refuses to start if either fails, so a wrong key surfaces immediately rather than silently at first request.

Because one MCP server process uses one configured Miniflux identity, every connected MCP client has that identity's permissions. This is the same trust model as `mcp-mastodon` and `mcp-forgejo` in this repo.

## Traefik

Set `COMPOSE_VARIANT=traefik`, configure `TRAEFIK_HOST`, and create the external `traefik` network to expose the MCP endpoint through the shared Traefik stack.

The Traefik client URL is:

```text
https://mcp-miniflux.example.com/mcp
```

The router uses the shared `websecure` entrypoint and `default-access@file` policy by default. Review the common [Traefik usage guide](../_docs/traefik.md) and [network setup](../_docs/traefik_network.md) before enabling this variant.

Do not expose this endpoint publicly without an appropriate access policy. The Bearer token is the only thing protecting `/mcp`, and any reverse-proxy authentication must preserve the `Authorization` header or use a different mechanism.

## Why no proxy variant

The `proxy` and `traefik_proxy` variants from `mcp-mastodon` are intentionally not available here. The upstream `miniflux.app/v2/client` Go client used by this server does not honour `HTTP_PROXY` / `HTTPS_PROXY`, so joining the external `proxy` network would silently do nothing. Track the missing feature in the upstream fork repo.
