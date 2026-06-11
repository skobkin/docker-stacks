# Forgejo MCP

[Forgejo MCP](https://codeberg.org/goern/forgejo-mcp) exposes Forgejo repositories, issues, pull requests, files, and other API operations to MCP clients over streamable HTTP.

## Setup

```shell
cp .env.dist .env
nano -w .env
docker compose up -d
```

Set `FORGEJO_URL` to the base URL of the Forgejo instance. The default MCP client URL is:

```text
http://127.0.0.1:8412/mcp
```

The port is bound to localhost by default. Change `BIND_ADDR` only when the endpoint is protected by an appropriate network or access-control layer.

This service joins the external [`ai-tools`](../_docs/ai_tools_network.md) Docker network so MCP clients and other AI services can reach it as `mcp-forgejo:8080`. Create the network before starting the stack:

```shell
docker network create ai-tools
```

## Authentication

By default, clients provide a Forgejo access token on each MCP request:

```text
Authorization: token <token>
Authorization: Bearer <token>
```

The schemes are case-insensitive. This per-request authentication allows different clients to use separate Forgejo identities through the same MCP server.

`FORGEJO_ACCESS_TOKEN` is optional. When set in `.env`, it becomes the global fallback identity for requests without an authorization token. A token supplied in the request header takes precedence over that fallback.

See the upstream [multi-tenant HTTP guide](https://github.com/goern/forgejo-mcp/blob/main/demos/multi-tenant-http.md) for protocol-level examples.

## Proxy Variant

Set `COMPOSE_VARIANT=proxy` when the server needs the external `proxy` network for outbound access through a service such as Mihomo. Create that network as documented in the shared [`proxy` network guide](../_docs/proxy_network.md), then uncomment the relevant proxy variables in `.env`.

## Traefik

Set `COMPOSE_VARIANT=traefik`, configure `TRAEFIK_HOST`, and create the external `traefik` network to expose the MCP endpoint through the shared Traefik stack. Use `COMPOSE_VARIANT=traefik_proxy` when both Traefik exposure and the outbound proxy network are required.

The Traefik client URL is:

```text
https://mcp-forgejo.example.com/mcp
```

The router uses the shared `websecure` entrypoint and `default-access@file` policy by default. Review the common [Traefik usage guide](../_docs/traefik.md) and [network setup](../_docs/traefik_network.md) before enabling this variant.

Do not expose this endpoint publicly without an appropriate access policy. Client-provided Forgejo tokens are carried in `Authorization` headers, so any reverse-proxy authentication must preserve those headers or use a different mechanism.
