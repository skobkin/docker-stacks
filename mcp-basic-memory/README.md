# Basic Memory MCP

[Basic Memory](https://github.com/basicmachines-co/basic-memory) turns an
Obsidian-compatible Markdown vault into a queryable knowledge base for LLM
clients over the Model Context Protocol. The streamable HTTP transport runs on
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
endpoint is protected by an appropriate network or access-control layer such as
a VPN, Tailnet, or Authelia in front of Traefik.

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

## Data integrity

Basic Memory state is split across two bind mounts so the index and the
markdown can be backed up, restored, or wiped independently:

| Host path | Container path | Contents |
|---|---|---|
| `HOST_MEMORY_DIR` (default `./memory`) | `/app/data` | One subdirectory per project with the markdown notes |
| `HOST_CONFIG_DIR` (default `./config`) | `/app/data/basic-memory` | `config.json`, `memory.db` (SQLite index), `watch-status.json`, `.bmignore`; also the implicit `main` project |

The implicit `main` project (from the upstream image's
`BASIC_MEMORY_HOME=/app/data/basic-memory`) shares the second path by
upstream's design. Remove it with `basic-memory project remove main` after
the first start if you do not want a default project.

To wipe just the index, `rm -rf ${HOST_CONFIG_DIR}/*` is safe — the vault
on `HOST_MEMORY_DIR` is untouched. See [Maintenance](#maintenance) for how
to rebuild.

## Maintenance

Three commands manage the index from outside the MCP protocol. Run them
inside the running container:

```shell
docker compose exec mcp-basic-memory basic-memory <command>
```

| Command | Purpose |
|---|---|
| `basic-memory project add <name> <path>` | Register an on-disk project directory in the database. Required for each project under `HOST_MEMORY_DIR/` — the MCP server does not auto-discover them. |
| `basic-memory status` | Show how much of the on-disk state is reflected in the database (which projects are registered, which files are indexed, how much is pending). |
| `basic-memory reindex` | Re-read the files on disk and update the database. Use `--full` for a complete rebuild; without it, only changed files are re-scanned. |

Project paths must live under `/app/data/` (the upstream image sets
`BASIC_MEMORY_PROJECT_ROOT=/app/data`). A typical registration:

```shell
docker compose exec mcp-basic-memory basic-memory project add your-project /app/data/your-project
```

To register everything under the vault root at once:

```shell
for d in "${HOST_MEMORY_DIR:-./memory}"/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  docker compose exec mcp-basic-memory basic-memory project add "$name" "/app/data/$name"
done
```

If the search index looks empty after edits on the host while the container
was down, run `basic-memory reindex --full` to rebuild it.

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

The streamable HTTP endpoint is **unauthenticated upstream** — Basic Memory's
own documentation warns:

> the HTTP endpoints have no authorization. They should not be exposed on a
> public network.

For the default `localhost` binding, protect access with the network layer
above (LAN, VPN, Tailnet, SSH tunnel). For the Traefik variant below, the
default `default-access@file` middleware routes requests through Authelia
before they reach the MCP server.

## Transport

The container runs the MCP server with the modern streamable HTTP transport
(MCP spec 2025-03-26) by default. Streamable HTTP is required by Codex and
accepted by OpenCode and Claude Code. The upstream image's `CMD` defaults to
the deprecated SSE transport, so the stack overrides it in `docker-compose.yml`.

`BASIC_MEMORY_TRANSPORT` in `.env` selects the transport:

- `streamable-http` (default) — recommended; required by Codex.
- `sse` — legacy; upstream marks it as deprecated. Use only if you need to
  roll back to a client that does not support streamable HTTP yet.

The transport is the only MCP-server flag the stack exposes; `--host`,
`--port`, and `--path` are hardcoded to the upstream defaults (`0.0.0.0`,
`8000`, `/mcp`).

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
which exercises the CLI binary and never touches the running streamable HTTP
server. The `docker-compose.yml` healthcheck overrides it with a TCP probe of
the listening port:

```yaml
healthcheck:
  test: ["CMD-SHELL", "bash -c 'exec 3<>/dev/tcp/127.0.0.1/8000 || exit 1'"]
```

The image is `python:3.12-slim-bookworm`, so `/bin/sh` is **dash**, not bash.
dash does not support `/dev/tcp/host/port` redirects, so the probe runs under
`bash -c`. `start_period: 30s` gives the uvicorn server time to start before
the first probe.

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
