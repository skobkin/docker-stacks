# Mastodon MCP

[Mastodon MCP](https://git.skobk.in/skobkin/mastodon-mcp) exposes instance metadata, accounts, timelines, notifications, statuses (read + post/reply/delete), follower removal, and aggregated account inspection to MCP clients over streamable HTTP. It works against any Mastodon 3.x/4.x or GoToSocial instance.

## Setup

```shell
cp .env.dist .env
nano -w .env
docker compose up -d
```

Set `MASTODON_MCP_MASTODON__BASE_URL` to the base URL of the Mastodon-compatible instance. The stack ships in `MASTODON_MCP_AUTH__MODE=request-header` (set in `docker-compose.yml`), so the MCP client sends the Mastodon access token on every request in `MASTODON_MCP_AUTH__REQUEST_HEADER` (default `X-Mastodon-Access-Token`); no token is configured server-side.

To run the server with a single baked-in identity instead, edit `docker-compose.yml` to set `MASTODON_MCP_AUTH__MODE` to `static` or `hybrid`, then uncomment one of:

- `MASTODON_MCP_AUTH__TOKEN` — inline token in `.env`.
- `MASTODON_MCP_AUTH__TOKEN_FILE` — path to a token file mounted into the container (Docker secret or read-only bind mount).

The upstream rejects both static sources being set at the same time. Any reverse proxy must forward `MASTODON_MCP_AUTH__REQUEST_HEADER` verbatim or `request-header` and `hybrid` modes silently break — see the *Reverse-proxy caveat* below.

The default MCP client URL is:

```text
http://127.0.0.1:8416/mcp
```

The health endpoint is `/healthz`. The port is bound to localhost by default. Change `BIND_ADDR` only when the endpoint is protected by an appropriate network or access-control layer.

This service joins the external [`ai-tools`](../_docs/ai_tools_network.md) Docker network so MCP clients and other AI services can reach it as `mcp-mastodon:8080`. Create the network before starting the stack:

```shell
docker network create ai-tools
```

## Authentication

Three modes, selected by `MASTODON_MCP_AUTH__MODE` (in `docker-compose.yml`):

- `request-header` (default): the token arrives on each MCP request via the
  configured Streamable HTTP header (default `X-Mastodon-Access-Token`).
  Requires the streamable HTTP transport.
- `static`: token or token file from configuration.
- `hybrid`: request header first, then the configured static fallback.

Per the upstream safety rules, access tokens are never accepted from MCP tool input or output. Tokens are only resolved from configuration or the configured request header.

## Reverse-proxy caveat

When the MCP server runs behind a reverse proxy, the proxy must forward the configured `auth.request_header` (default `X-Mastodon-Access-Token`) verbatim. Removing or rewriting the header silently breaks `request-header` and `hybrid` auth modes. The proxy should also forward the client-supplied `Origin` header so the server's `allowed_origins` allowlist can run.

## Proxy Variant

Set `COMPOSE_VARIANT=proxy` when the server needs the external `proxy` network for outbound access through a service such as Mihomo. Create that network as documented in the shared [`proxy` network guide](../_docs/proxy_network.md), then uncomment the relevant proxy variables in `.env`. Two equivalent forms are available:

- The Go-style `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` triple (honoured because `MASTODON_MCP_HTTP__PROXY_FROM_ENVIRONMENT` defaults to `true`).
- The explicit upstream override `MASTODON_MCP_HTTP__PROXY_URL=socks5://mihomo:1050` (recommended when only one proxy is needed; it bypasses the environment lookup).

## Traefik

Set `COMPOSE_VARIANT=traefik`, configure `TRAEFIK_HOST`, and create the external `traefik` network to expose the MCP endpoint through the shared Traefik stack. Use `COMPOSE_VARIANT=traefik_proxy` when both Traefik exposure and the outbound proxy network are required.

The Traefik client URL is:

```text
https://mcp-mastodon.example.com/mcp
```

The router uses the shared `websecure` entrypoint and `default-access@file` policy by default. Review the common [Traefik usage guide](../_docs/traefik.md) and [network setup](../_docs/traefik_network.md) before enabling this variant.

Do not expose this endpoint publicly without an appropriate access policy. Client-provided Mastodon tokens are carried in `X-Mastodon-Access-Token` (or the configured alternative), so any reverse-proxy authentication must preserve that header or use a different mechanism.
