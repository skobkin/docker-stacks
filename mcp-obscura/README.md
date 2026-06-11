# Obscura MCP

[Obscura](https://github.com/h4ckf0r0day/obscura) is a headless browser written in Rust. This stack runs its [streamable HTTP MCP server](https://github.com/h4ckf0r0day/obscura/blob/main/docs/Use-the-MCP-server.md) with one browser session shared by clients of the container.

## Setup

```shell
cp .env.dist .env
nano -w .env
docker compose up -d
```

The default MCP client URL is:

```text
http://127.0.0.1:8413/mcp
```

The port is bound to localhost by default. Change `BIND_ADDR` only when the endpoint is protected by an appropriate network or access-control layer.

This stack requires an Obscura image whose `mcp` command supports `--host`. The command binds to `0.0.0.0:3000` inside the container so the endpoint is reachable through the localhost-published port and optional Traefik network.

## Security

Obscura's MCP HTTP server has no built-in authentication. Any client that can reach it can control the shared browser session, navigate to URLs, read page contents, and execute the exposed browser tools. Keep the default localhost binding or add authentication and restrictive access control at the reverse proxy.

`OBSCURA_MCP_ALLOWED_ORIGINS` is an optional comma-separated allowlist for browser callers. Browser requests carrying an `Origin` header must match an entry. Native MCP clients without an `Origin` header are always allowed, so this setting is a browser-origin safeguard rather than authentication. When it is empty, Obscura permits all origins.

## Variants

Set `COMPOSE_VARIANT` in `.env`:

| Variant                   | Behavior                                      |
|---------------------------|-----------------------------------------------|
| `default`                 | Local MCP endpoint only                       |
| `stealth`                 | Adds Obscura's `--stealth` mode               |
| `proxy`                   | Routes browser requests through a proxy       |
| `stealth_proxy`           | Combines stealth and proxy behavior           |
| `traefik`                 | Adds Traefik routing                          |
| `traefik_stealth`         | Combines Traefik routing and stealth          |
| `traefik_proxy`           | Combines Traefik routing and proxying         |
| `traefik_stealth_proxy`   | Enables Traefik, stealth, and proxying        |

The current upstream Dockerfile builds without the optional Cargo `stealth` feature. The `--stealth` flag still enables tracker blocking in that image, but TLS fingerprint impersonation requires an upstream image built with the feature.

## Proxy

Proxy variants join the external [`proxy`](../_docs/proxy_network.md) network and default to Mihomo at `socks5://mihomo:1050`. Override `OBSCURA_PROXY` for another HTTP or SOCKS5 proxy.

Obscura configures the supplied URL as an [all-requests proxy](https://github.com/h4ckf0r0day/obscura/blob/main/crates/obscura-net/src/client.rs) and currently has no bypass-list equivalent. This stack therefore does not expose `HTTP_PROXY`, `HTTPS_PROXY`, or `NO_PROXY`.

Create the network before starting a proxy variant:

```shell
docker network create proxy
```

## Traefik

Traefik variants join the external [`traefik`](../_docs/traefik_network.md) network and route container port `3000` through the shared `websecure` entrypoint. The default access policy is `default-access@file`.

The Traefik MCP client URL is:

```text
https://mcp-obscura.example.com/mcp
```

Create the network, set `TRAEFIK_HOST`, and review the shared [Traefik usage guide](../_docs/traefik.md) before enabling a Traefik variant. Do not expose this endpoint publicly without adding authentication.

## CDP

MCP mode does not open Obscura's Chrome DevTools Protocol listener. CDP access requires a separate `obscura serve` process and uses an independent browser session; it is intentionally outside this stack.
