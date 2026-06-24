## 2026-06-25 - Basic Memory MCP: streamable HTTP transport and persistent index

### Affected stacks

- `mcp-basic-memory`

### Explanation

Two changes to the Basic Memory MCP stack ship together:

**Streamable HTTP transport.** The container now runs MCP with the
streamable HTTP transport (`basic-memory mcp --transport streamable-http`)
instead of the deprecated SSE transport. Streamable HTTP is the modern MCP
transport (spec 2025-03-26) and is required by Codex, which sends the MCP
`initialize` handshake as `POST /mcp` and previously received
`HTTP 405 Method Not Allowed` from the SSE-only backend. OpenCode and
Claude Code accept either transport and continue to work without
configuration changes. The upstream image's `CMD` still defaults to SSE,
so the stack now overrides it in `docker-compose.yml`. The listening port
(container `8000`), endpoint path (`/mcp`), and host binding (`0.0.0.0`)
are unchanged. The new `BASIC_MEMORY_TRANSPORT` env var defaults to
`streamable-http`.

**Persistent index on the config bind mount.** The compose file now
overrides the upstream default of `BASIC_MEMORY_HOME=/app/data/basic-memory`
(a hidden subdirectory of the vault) to `BASIC_MEMORY_HOME=/app/.basic-memory`.
The CLI's SQLite index (`memory.db`) and per-project metadata
(`config.json`) therefore live on the `HOST_CONFIG_DIR` bind mount (default
`./config`) instead of being buried inside `HOST_MEMORY_DIR`. This makes
the `HOST_CONFIG_DIR` mount serve the purpose its name suggests — the
stack now genuinely splits "what I wrote" (`HOST_MEMORY_DIR`) from
"the search index over what I wrote" (`HOST_CONFIG_DIR`). Both can be
backed up, restored, or wiped independently. The previous layout was
internally inconsistent: `HOST_CONFIG_DIR` mounted `/app/.basic-memory`
but the CLI never read that path, so the mount was a silent no-op and
the index drifted on any host that did not happen to back up the
hidden `./memory/basic-memory/` subdirectory. `BASIC_MEMORY_PROJECT_ROOT`
keeps the upstream default of `/app/data`, so the markdown vault itself
is unchanged — only the index location moves.

The container's `command:` does **not** run `basic-memory sync` on start.
The index is expected to be persistent across recreates and re-syncing
on every boot would mask real index-loss bugs. A new "Repairing index"
section in `mcp-basic-memory/README.md` documents the manual recovery
procedure (`docker compose exec mcp-basic-memory basic-memory project add …`
followed by `basic-memory reindex --full`) for the cases where state
genuinely needs rebuilding — fresh host, partial restore, or migration
from the old layout. Note that the current `latest` upstream image does
not expose a top-level `sync` command; project registration is the
explicit recovery path.

### Migration

1. Pull the updated `mcp-basic-memory/docker-compose.yml` and recreate
   the stack: `cd mcp-basic-memory && docker compose up -d --force-recreate`.
   The new container runs with `--transport streamable-http` and the
   `BASIC_MEMORY_HOME=/app/.basic-memory` redirect.

2. **If you are upgrading from a previous version of this stack** that
   was running with the old layout (index at
   `${HOST_MEMORY_DIR:-./memory}/basic-memory/`), copy the existing index
   to the new location **before** the first recreate, otherwise the new
   container starts with a fresh empty index:

   ```shell
   cp -a "${HOST_MEMORY_DIR:-./memory}/basic-memory/." \
         "${HOST_CONFIG_DIR:-./config}/"
   cd mcp-basic-memory && docker compose up -d --force-recreate
   ```

   Operators who do not have an existing index to migrate (the previous
   container was running with an empty `./memory/basic-memory/`), or who
   don't mind waiting for a rebuild, can skip the `cp` and instead start
   clean and re-register the on-disk projects. The MCP server does not
   auto-discover subdirectories of `BASIC_MEMORY_PROJECT_ROOT`, so each
   project directory under `${HOST_MEMORY_DIR:-./memory}/` has to be
   registered explicitly:

   ```shell
   cd mcp-basic-memory
   for d in "${HOST_MEMORY_DIR:-./memory}"/*/; do
     [ -d "$d" ] || continue
     name=$(basename "$d")
     docker compose exec mcp-basic-memory basic-memory project add "$name" "/app/data/$name"
   done
   # Optional: force a full rebuild of the search/vector indexes
   docker compose exec mcp-basic-memory basic-memory reindex --full
   ```

3. To roll back, edit `mcp-basic-memory/.env` and set
   `BASIC_MEMORY_TRANSPORT=sse` to restore the legacy transport, and
   remove the two new `BASIC_MEMORY_HOME` / `BASIC_MEMORY_PROJECT_ROOT`
   lines from the `environment:` block of `mcp-basic-memory/docker-compose.yml`
   to restore the old index layout (placing the index at
   `${HOST_MEMORY_DIR}/basic-memory/`). There is no env-var toggle for
   the index location — the `BASIC_MEMORY_HOME` redirect is a
   compose-level override.

## 2026-06-12 - Abandoned stacks removed

### Affected stacks

- `drone`
- `drone-runner`
- `homer`
- `magnetico-web-telegram`
- `open-streaming-platform`
- `shinobi`
- `proxy-mtproto`
- `duplicati`
- `metube`
- `shadowsocks-client`
- `v2fly-client`

### Explanation

These stacks were marked abandoned (⏸) in the README and have been removed per #274. Drone and Drone Docker Runner were already replaced by Woodpecker CI in this repository. magnetico-web-telegram was superseded by newer magnetico-web. Homer, Open Streaming Platform, Shinobi, and Metube have dormant upstream projects. proxy-mtproto is replaced by `proxy-socks5` or external Rust MTProto proxies. Duplicati, Shadowsocks Client, and V2Fly Client were marked abandoned with no current operator use.

`folding-at-home` is now marked abandoned (⏸) but kept in the repository.

### Migration

1. For each removed stack currently running: `cd <stack> && docker compose down` and archive or remove the stack's `data/` directory manually.
2. Drone users should already be on Woodpecker (`woodpecker/`, `woodpecker-agent/`). Disable the Drone server and runner containers and remove any DNS or reverse-proxy entries pointing at them.
3. magnetico-web-telegram users can remove the bot and use magnetico-web directly.
4. proxy-mtproto users should switch to `proxy-socks5` (HTTP/SOCKS5) or a maintained MTProto proxy image.
5. v2fly-client users should switch to the `mihomo` stack (same default SOCKS, HTTP, and TProxy host ports).
6. No other operator action is required; the repo's CI now validates one fewer compose file per stack.

## 2026-06-11 - Webhook.site replaced by WebHook Tester

### Affected stacks

- `webhooksite`
- `webhook-tester`

### Explanation

The multi-container Webhook.site stack has been removed and replaced by the single-container WebHook Tester stack. The new stack stores sessions and captured requests on the filesystem under `webhook-tester/data` by default and listens on localhost port `8414`.

Existing Webhook.site sessions and Redis data are not compatible with WebHook Tester and cannot be migrated automatically.

### Migration

1. Stop the old stack with `cd webhooksite && docker compose down`.
2. Archive or remove the old `webhooksite/data` directory manually after confirming it is no longer needed.
3. Change to `webhook-tester`, copy `.env.dist` to `.env`, and review the UID/GID and storage settings.
4. Update local integrations and bookmarks from port `8391` to `8414`.
5. When using Traefik for webhook providers outside the private network, explicitly set `TRAEFIK_ACCESS_POLICY=public-access@file` and configure `PUBLIC_URL_ROOT`.
6. Start the new stack with `docker compose up -d`.

## 2026-06-05 - qBittorrent resource limits added

### Affected stacks

- `qbittorrent`

### Explanation

The qBittorrent stack now has configurable Compose resource limits. By default, the container is limited to 4 CPUs and 4 GB of memory through `CPU_LIMIT` and `MEMORY_LIMIT` in `.env`.

## 2026-05-18 - Telegram LLM Bot 0.20.0 configuration update

### Affected stacks

- `telegram-llm-bot`

### Explanation

The stack now targets `skobkin/telegram-llm-bot:0.20.0`, mounts persistent data at `/data`, and uses the bot's new OpenAI-compatible LLM, SQLite, state-limit, tool-use, and optional search environment variables. The old `OPENAI_API_*` and `MODEL_*` variables were replaced by `LLM_BACKEND_OPENAI_COMPAT_*` and `LLM_FEATURE_*` variables.

External network membership is now optional. The default variant uses only the stack-local Docker network; set `COMPOSE_VARIANT=ai_tools`, `COMPOSE_VARIANT=proxy`, or `COMPOSE_VARIANT=ai_tools_proxy` when the bot needs those external networks.

### Migration

1. Copy the new variables from `telegram-llm-bot/.env.dist` into the local `telegram-llm-bot/.env`.
2. Replace `IMAGE_VERSION` with `IMAGE_TAG`.
3. Set `COMPOSE_VARIANT=`
   - `ai_tools` if the bot uses repo-local `llama-swap` or `ollama`.
   - `proxy` if the bot needs the external `proxy` network.
   - `ai_tools_proxy` if both external networks are needed.
4. Replace `OPENAI_API_BASE_URL` with `LLM_BACKEND_OPENAI_COMPAT_BASE_URL`.
5. Use `http://llama-swap:8080/v1` for the repo-local llama-swap stack, or `http://ollama:11434/v1` for the repo-local Ollama stack.
6. Replace `OPENAI_API_TOKEN` with `LLM_BACKEND_OPENAI_COMPAT_API_TOKEN`.
7. Replace `MODEL_TEXT_REQUEST` with `LLM_FEATURE_CHAT_MODEL`.
8. Replace `MODEL_SUMMARIZE_REQUEST` with `LLM_FEATURE_SUMMARIZE_MODEL`.
9. Remove old prompt/persona env variables; they are now seeded into SQLite and managed through Telegram admin DMs.
10. Set `BOT_ADMIN_IDS` if admin controls are needed.
11. Recreate the container.

## 2026-05-15 - Speedtest Rust image refresh

### Affected stacks

- `speedtest`

### Explanation

The stack now uses the maintained LibreSpeed Rust image (`ghcr.io/librespeed/speedtest-rust`) instead of the old `adolfintel/speedtest` image. The Compose file also supports overriding `IMAGE_TAG`, `HTTP_BIND_ADDR`, `HTTP_BIND_PORT`, and `HOST_CONFIG_FILE` from `.env`.

### Migration

Copy new variables from `speedtest/.env.dist` into the local `speedtest/.env`, copy `speedtest/config/configs.toml.dist` to `speedtest/config/configs.toml`, review the Rust backend settings, and recreate the container. The default template sets `database_type = "none"`; uncomment the SQLite option if local telemetry/statistics storage is needed. SQLite data is stored under `HOST_DATA_DIR` (`./data` by default).

## 2026-05-15 - Authelia SSO and shared Redis network support

### Affected stacks

- `authelia`
- `redis`
- `traefik`

### Explanation

Authelia was added as an optional SSO portal and Traefik forward-auth provider. Traefik's `public-access.yml.dist` now also defines `public-auth-access@file` for services that want Authelia in front of public routes, and the Traefik dashboard middleware chain can be overridden with `TRAEFIK_DASHBOARD_MIDDLEWARES`.

The shared `redis` stack now joins the external `databases` network by default so stacks such as Authelia can use it as `redis:6379` for optional session storage.

### Migration

Create the external `databases` network before starting `redis` if it does not already exist. For Traefik SSO, copy `traefik/config/dynamic/public-access.yml.dist` to `traefik/config/dynamic/public-access.yml`, start the Authelia stack on the same `traefik` network, and set protected services to `TRAEFIK_ACCESS_POLICY=public-auth-access@file`.

## 2026-05-13 - Traefik default access policy added

### Affected stacks

- `traefik`
- all stacks using `COMPOSE_VARIANT=traefik` or a combined Traefik variant

### Explanation

Traefik routers now apply `${TRAEFIK_ACCESS_POLICY:-default-access@file}` before their stack-specific middlewares. This centralizes the default private/public access decision in the Traefik file-provider config while still allowing per-stack overrides such as `TRAEFIK_ACCESS_POLICY=public-access@file`.

### Migration

Copy `traefik/config/dynamic/default-access.yml.dist` to `traefik/config/dynamic/default-access.yml`, then edit the live file and leave exactly one `default-access` definition uncommented. Use the private LAN allow-list example for private-by-default routing, or the public example if your existing routers should remain reachable from any IPv4 or IPv6 source.

For a stack that should be public while the shared default stays private, copy `traefik/config/dynamic/public-access.yml.dist` to `traefik/config/dynamic/public-access.yml` and set `TRAEFIK_ACCESS_POLICY=public-access@file` in that stack's `.env`.

## 2026-05-13 - qBittorrent networking simplified

### Affected stacks

- `qbittorrent`

### Explanation

`network_mode` is now hardcoded to `host`. The overridable `NETWORK_MODE` variable was removed. Host networking is required for qBittorrent to discover local peers properly.

### Migration

Remove `NETWORK_MODE=bridge` from your local `.env` if present. The stack now always runs with `network_mode: host`.

## 2026-05-12 - ESPHome networking hardened to host mode

### Affected stacks

- `esphome`

### Explanation

`network_mode` is now hardcoded to `host` and the overridable `NETWORK_MODE` variable has been removed. The container must always run in host networking mode to properly look for devices in the same network.

### Migration

Existing `.env` files that set `NETWORK_MODE=bridge` will silently be ignored — the stack now runs with `network_mode: host` regardless. Remove the `NETWORK_MODE` line from your local `.env` if present.

## 2026-05-12 - Emby WEBUI_BIND_ADDR now defaults to 127.0.0.1

### Affected stacks

- `emby`

### Explanation

`WEBUI_BIND_ADDR` default changed from `0.0.0.0` to `127.0.0.1`. The web UI will no longer bind to all interfaces on first start unless explicitly configured otherwise.

### Migration

To retain the old behavior, set `WEBUI_BIND_ADDR=0.0.0.0` in your local `.env`. If you plan to use Traefik with `COMPOSE_VARIANT=traefik`, the `127.0.0.1` default is recommended and no change is needed.

## 2026-05-02 - Traefik HTTP/3 enabled

### Affected stacks

- `traefik`

### Explanation

The shared Traefik `websecure` entrypoint now enables HTTP/3 by default and publishes UDP on the HTTPS port. Existing TCP HTTP and HTTPS behavior is unchanged.

### Migration

Allow UDP traffic to `HTTPS_UDP_BIND_PORT` if clients should use HTTP/3. If another service already owns that UDP port, change `HTTPS_UDP_BIND_PORT` or disable HTTP/3 in the local Traefik environment before recreating the stack.

## 2026-05-02 - Optional shared on-host database network added

### Affected stacks

- `castopod`
- `forgejo`
- `gotosocial`
- `hedgedoc`
- `magneticod`
- `magnetico-web`
- `miniflux`
- `synapse`
- `tg-rss-bot`
- `woodpecker`

### Explanation

These stacks can now opt into the shared external `databases` Docker network with `COMPOSE_VARIANT=databases`. Stacks that also support Traefik can use `COMPOSE_VARIANT=traefik_databases` to enable both optional network attachments.

The shared network is intended for bare-metal databases running on the Docker host and can also be used by shared database containers.

The default variants are unchanged and do not require the `databases` network.

### Migration

For a bare-metal host database, create the shared network with a stable gateway, for example `docker network create --subnet 172.30.10.0/24 --gateway 172.30.10.1 databases`. Make the database listen on `172.30.10.1`, allow clients from `172.30.10.0/24`, set the affected stack to `COMPOSE_VARIANT=databases` or `COMPOSE_VARIANT=traefik_databases`, and update the stack database host or DSN to use `172.30.10.1`.

For a shared database container, attach the database container to the `databases` network and use the database container name in the stack database host or DSN.
