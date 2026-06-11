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
