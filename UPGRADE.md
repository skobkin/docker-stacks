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
