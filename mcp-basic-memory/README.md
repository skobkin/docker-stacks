# Basic Memory MCP

[Basic Memory](https://github.com/basicmachines-co/basic-memory) turns an
Obsidian-compatible Markdown vault into a queryable knowledge base for LLM
clients over the Model Context Protocol. The HTTP/SSE transport runs on
container port `8000` and exposes the MCP endpoint at `/mcp`.

## Setup

```shell
cp .env.dist .env
nano -w .env
docker compose up -d
```

The default MCP client URL is:

```text
http://127.0.0.1:8415/mcp
```

The port is bound to localhost by default. Change `BIND_ADDR` only when the
endpoint is protected by an appropriate network or access-control layer such
as a VPN, Tailnet, or Authelia in front of Traefik.

This service joins the external [`ai-tools`](../_docs/ai_tools_network.md)
Docker network so MCP clients and other AI services can reach it as
`mcp-basic-memory:8000`. Create the network before starting the stack:

```shell
docker network create ai-tools
```

## Memory directory

The knowledge base lives at `/app/data` inside the container and is
bind-mounted from `HOST_MEMORY_DIR` (default `./memory`). The stack ships
this directory as empty with a `.gitignore` that ignores its contents — the
files Basic Memory writes are runtime data and should not be committed. Use a
**dedicated memory directory**, not your whole Obsidian vault — Basic Memory
is designed to write and rewrite Markdown files in this directory as it
indexes and synthesises notes, which is not appropriate for the rest of your
vault.

Because the directory is bind-mounted, you can open it directly in Obsidian
(File → Open vault → Open folder as vault) to browse and edit notes with the
full Obsidian experience.

## Config directory

The Basic Memory CLI config and SQLite knowledge-base index live at
`/app/.basic-memory` inside the container and are bind-mounted from
`HOST_CONFIG_DIR` (default `./config`). This directory is also shipped empty
with a content-blocking `.gitignore`. Keeping the index on the host (instead
of in a Docker named volume) means it backs up alongside the markdown and
can be inspected or migrated without `docker volume` plumbing.

## Filesystem permissions

The upstream image runs as a non-root `appuser` with **hardcoded UID/GID
1000** (set at build time, not overridable via env vars). On Linux hosts,
grant ownership before the first start so the container can read and write
notes:

```shell
mkdir -p memory config
chown -R 1000:1000 memory config
```

If your host UID/GID is not 1000, you have two options:

1. Continue with UID/GID 1000 and accept the apparent ownership mismatch in
   `ls -l` output — the container will still read and write correctly.
2. Rebuild the image locally with build args matching your UID/GID, then
   point `IMAGE_TAG` at the local tag. This requires a `Dockerfile`; the
   upstream image does not currently expose these as build args.

## Authentication

The HTTP/SSE endpoint is **unauthenticated upstream** — Basic Memory's own
documentation warns:

> the HTTP endpoints have no authorization. They should not be exposed on a
> public network.

For the default `localhost` binding, protect access with the network layer
above (LAN, VPN, Tailnet, SSH tunnel). For the Traefik variant below, the
default `default-access@file` middleware routes requests through Authelia
before they reach the MCP server.

## Traefik

Set `COMPOSE_VARIANT=traefik`, configure `TRAEFIK_HOST`, and create the
external `traefik` network to expose the MCP endpoint through the shared
Traefik stack. See the common [Traefik usage guide](../_docs/traefik.md)
and [network setup](../_docs/traefik_network.md) before enabling this
variant.

The Traefik client URL is:

```text
https://mcp-basic-memory.example.com/mcp
```

The router uses the shared `websecure` entrypoint and `default-access@file`
policy by default. To intentionally expose the endpoint publicly (e.g. for a
publicly writable memory vault), override `TRAEFIK_ACCESS_POLICY` to
`public-access@file`.

## Healthcheck

The upstream image's `HEALTHCHECK` directive runs `basic-memory --version`,
which exercises the CLI binary and never touches the running SSE server. The
`docker-compose.yml` healthcheck overrides it with a TCP probe of the
listening port:

```yaml
healthcheck:
  test: ["CMD-SHELL", "bash -c 'exec 3<>/dev/tcp/127.0.0.1/8000 || exit 1'"]
```

The image is `python:3.12-slim-bookworm`, so `/bin/sh` is **dash**, not bash.
dash does not support `/dev/tcp/host/port` redirects and treats the path as a
literal filename, so a naive `exec 3<>/dev/tcp/127.0.0.1/8000` under
`CMD-SHELL` fails on every probe and Docker marks the container unhealthy
permanently. The image ships with `/bin/bash` (the non-root `appuser`'s login
shell), so we run the probe under `bash -c`. `start_period: 30s` gives the
uvicorn server time to start before the first probe.

## Image tag policy

`.env.dist` defaults `IMAGE_TAG=latest` because Basic Memory ships releases
rapidly. This is an explicit deviation from the general guidance in
[`AGENTS.md`](../AGENTS.md) that prefers explicit stable tags. Operators who
want reproducibility or want watchtower to apply only compatible updates
should pin to a specific upstream tag (for example `v0.22.1`).

## References

- [basicmachines-co/basic-memory](https://github.com/basicmachines-co/basic-memory)
- [Upstream Docker docs](https://github.com/basicmachines-co/basic-memory/blob/main/docs/Docker.md)
- [Per-project routing spec](https://github.com/basicmachines-co/basic-memory/blob/main/docs/SPEC-PER-PROJECT-ROUTING.md)
- [Issue #330](https://git.skobk.in/skobkin/docker-stacks/issues/330)
