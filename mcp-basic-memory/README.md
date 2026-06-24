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
| `HOST_CONFIG_DIR` (default `./config`) | `/app/data/basic-memory` | `config.json`, `memory.db` (the SQLite index), `watch-status.json`, `.bmignore`; also the implicit `main` project (see below) | The search/relations graph without rebuilding it |

Upstream separates two concerns that look like one path:

- `BASIC_MEMORY_CONFIG_DIR` — the CLI's "config dir" returned by
  `resolve_data_dir()` in upstream `config.py`. The SQLite index,
  `config.json`, `watch-status.json`, and `.bmignore` all live here. The
  default when unset is `~/.basic-memory` (i.e.
  `/home/appuser/.basic-memory/` inside the container). The
  `docker-compose.yml` overrides this to `/app/data/basic-memory` so the
  bind mount is honoured.
- `BASIC_MEMORY_HOME` — the default path for the implicit `main` project.
  The Dockerfile sets this to `/app/data/basic-memory`, which coincides
  with `BASIC_MEMORY_CONFIG_DIR` by design. On the first start,
  `BasicMemoryConfig.model_post_init` creates `main` at this path.

With both pointing at the same dir, the index and the implicit `main`
project vault live side by side under `HOST_CONFIG_DIR`. If you have notes
in `main` it works, but the stack is designed around per-project
subdirectories of `HOST_MEMORY_DIR`. The cleanest way to opt out of the
implicit `main` is to remove it after the first start:

```shell
docker compose exec mcp-basic-memory basic-memory project remove main
# Then set BASIC_MEMORY_DEFAULT_PROJECT in .env to one of the real projects
# (e.g. docker-stacks) so the MCP `default_project` resolution still finds
# a valid project.
```

If you ever need to wipe just the index (for example to test a clean
re-sync, or to recover from index corruption), `rm -rf ${HOST_CONFIG_DIR}/*`
is safe — the vault on `HOST_MEMORY_DIR` is untouched and the index can be
rebuilt with [Repairing index](#repairing-index) below.

## Repairing index

The container does not run a background `sync` on start — the SQLite
index at `HOST_CONFIG_DIR/memory.db` and the project registry in
`HOST_CONFIG_DIR/config.json` are expected to be persistent across
recreates, so a normal start should not need to rebuild anything. Use the
manual recovery procedure below when state genuinely needs rebuilding.

> The `latest` upstream image does **not** expose a top-level `sync`
> command. The two commands that matter for recovery are
> [`project add`](https://github.com/basicmachines-co/basic-memory/blob/main/docs/SPEC-PER-PROJECT-ROUTING.md)
> (registers an existing on-disk directory as a project — required because
> the MCP server does **not** auto-discover subdirectories of
> `BASIC_MEMORY_PROJECT_ROOT`) and
> [`reindex`](https://github.com/basicmachines-co/basic-memory/blob/main/src/basic_memory/cli/commands/db.py)
> (rebuilds the search/vector indexes for already-registered projects).

When to repair:

- **Index was wiped.** `${HOST_CONFIG_DIR}` is empty or missing
  `memory.db` — for example after a fresh host setup, a partial restore
  from backup, or a manual `rm -rf`. The MCP server will start but
  `list_memory_projects` will show only the default `main`.
- **Projects on disk are not registered.** You have directories under
  `HOST_MEMORY_DIR/` that should appear as projects, but the MCP
  `list_projects` tool returns only the default `main`. The MCP server
  does not auto-discover subdirectories of `BASIC_MEMORY_PROJECT_ROOT`,
  so each one has to be registered with `project add`.
- **Index is stale.** You added or edited notes on disk while the MCP
  container was down (or via a non-container Basic Memory CLI) and want
  the search index to pick them up.
- **Migrating from the old layout.** You previously ran a version of this
  stack where the index lived at `${HOST_MEMORY_DIR}/basic-memory/` (a
  subdirectory of the vault) and want to move it to the new
  `HOST_CONFIG_DIR` mount.

### Re-registering projects on disk

The MCP server reads the project list from `HOST_CONFIG_DIR/config.json`
and the `projects` SQLite table. When the index is fresh but the vault
already contains project directories, register each one explicitly. From
the stack directory:

```shell
cd mcp-basic-memory

# List what is on disk first — each top-level directory under
# HOST_MEMORY_DIR is a candidate project.
ls -1 "${HOST_MEMORY_DIR:-./memory}"

# Register each one. <name> is the display name in the MCP `list_projects`
# tool; <path> is the absolute path inside the container (/app/data maps
# to HOST_MEMORY_DIR on the host).
docker compose exec mcp-basic-memory basic-memory project add docker-stacks /app/data/docker-stacks
docker compose exec mcp-basic-memory basic-memory project add slopgame     /app/data/slopgame
# Repeat for any other directories shown by `ls -1`.
```

`project add` writes to `HOST_CONFIG_DIR/config.json` and the
`projects` SQLite table in the same database the MCP server reads, so
no container restart is needed — the next MCP request sees the
registered projects. The MCP server's background `WatchService` then
indexes each registered project's files on disk into the search index
automatically.

> **Path constraint.** The upstream image sets
> `BASIC_MEMORY_PROJECT_ROOT=/app/data`, so `project add` rejects any
> path outside `/app/data/`. If you have a project whose vault lives
> elsewhere (e.g. an older deployment that registered it at
> `/basic-memory` instead of `/app/data/basic-memory`), `project remove`
> it first and re-add it with the correct path.

A loop is convenient for many projects:

```shell
cd mcp-basic-memory
for d in "${HOST_MEMORY_DIR:-./memory}"/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  docker compose exec mcp-basic-memory basic-memory project add "$name" "/app/data/$name"
done
```

### Force a full reindex

If the projects are registered but the search index is stale (for
example after editing many files while the container was down), force a
full re-scan of every registered project:

```shell
cd mcp-basic-memory
docker compose exec mcp-basic-memory basic-memory reindex --full
```

`reindex --full` rebuilds the file-backed full-text search index and
re-embeds notes (when semantic search is enabled). It does not change
the project list — for that, use `project add` above. Watch progress
with:

```shell
docker compose logs -f mcp-basic-memory
```

For the migrating-from-old-layout case, the previous index lived in
the container's home directory (`/home/appuser/.basic-memory/`) which
was never bind-mounted to the host, so it was lost on every recreate
anyway. Wipe the config dir and start clean — the markdown on
`HOST_MEMORY_DIR` is the source of truth:

```shell
rm -rf "${HOST_CONFIG_DIR:-./config}"/*
docker compose up -d --force-recreate
# Then re-register each on-disk project (see above) and run
# `basic-memory reindex --full` if the search index looks empty.
```

If the rebuild succeeds but only some projects reappear, or
`project add` errors out, the most likely cause is a permissions
mismatch: the `appuser` (UID/GID 1000) inside the container cannot
read one of the project directories. See
[Filesystem permissions](#filesystem-permissions) and run
`chown -R 1000:1000 ${HOST_MEMORY_DIR} ${HOST_CONFIG_DIR}` before
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
