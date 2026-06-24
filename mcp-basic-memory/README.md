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

## Data integrity

Basic Memory state is split across the two bind mounts so the index and the
markdown can be backed up, restored, or wiped independently:

| Host path | Container path | Contents | Back up to preserve |
|---|---|---|---|
| `HOST_MEMORY_DIR` (default `./memory`) | `/app/data` | One subdirectory per project with the markdown notes | The notes themselves |
| `HOST_CONFIG_DIR` (default `./config`) | `/app/.basic-memory` | `config.json`, `memory.db` (the SQLite index), per-project metadata | The search/relations graph without rebuilding it |

The compose file overrides the upstream default of
`BASIC_MEMORY_HOME=/app/data/basic-memory` (a subdirectory of the vault) to
`BASIC_MEMORY_HOME=/app/.basic-memory` so the two bind mounts hold
independent data. This is the only way the `HOST_CONFIG_DIR` mount serves a
real purpose; without the override the CLI never reads `/app/.basic-memory`
and `./config/` would be a no-op.

If you ever need to wipe just the index (for example to test a clean
re-sync, or to recover from index corruption), `rm -rf ${HOST_CONFIG_DIR}/*`
is safe — the vault on `HOST_MEMORY_DIR` is untouched and the index can be
rebuilt with [Repairing index](#repairing-index) below.

## Repairing index

The container does not run `basic-memory sync` on start — the SQLite index
at `HOST_CONFIG_DIR/memory.db` is expected to be persistent across
recreates, so a normal start should not need to rebuild anything. Use the
manual recovery procedure below when the index genuinely needs rebuilding.

When to repair:

- **Index was wiped.** `${HOST_CONFIG_DIR}` is empty or missing
  `memory.db` — for example after a fresh host setup, a partial restore
  from backup, or a manual `rm -rf`. The MCP server will start but
  `list_memory_projects` will show only the default `main`.
- **Index is stale.** You added or edited notes on disk while the MCP
  container was down (or via a non-container Basic Memory CLI) and want
  the index to pick them up.
- **Migrating from the old layout.** You previously ran a version of this
  stack where the index lived at `${HOST_MEMORY_DIR}/basic-memory/` (a
  subdirectory of the vault) and want to move it to the new
  `HOST_CONFIG_DIR` mount.

The repair walks `BASIC_MEMORY_PROJECT_ROOT` (= `/app/data` =
`HOST_MEMORY_DIR`) and reconciles `HOST_CONFIG_DIR/memory.db` against the
current markdown. It is idempotent: an already-in-sync index exits
quickly with no visible work; a missing or stale index rebuilds whatever
is needed.

```shell
cd mcp-basic-memory
docker compose exec mcp-basic-memory basic-memory sync
```

Sync writes to the same SQLite database the MCP server reads, so no
container restart is needed afterward — the next MCP request sees the
rebuilt index. Watch progress with:

```shell
docker compose logs -f mcp-basic-memory
```

For the migrating-from-old-layout case, the index is already on disk but
at the old path. Copy it across before recreating, or just let the sync
rebuild it:

```shell
# Option A — preserve the existing index (faster, no re-indexing needed)
cp -a "${HOST_MEMORY_DIR:-./memory}/basic-memory/." "${HOST_CONFIG_DIR:-./config}/"
docker compose up -d --force-recreate

# Option B — start clean and let sync rebuild from the markdown
docker compose exec mcp-basic-memory basic-memory sync
```

If the rebuild succeeds but only some projects reappear, or sync errors
out, the most likely cause is a permissions mismatch: the `appuser`
(UID/GID 1000) inside the container cannot read one of the project
directories. See [Filesystem permissions](#filesystem-permissions) and
run `chown -R 1000:1000 ${HOST_MEMORY_DIR} ${HOST_CONFIG_DIR}` before
retrying.

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
