# Continuwuity

This stack runs the [Continuwuity](https://github.com/continuwuity/continuwuity) Matrix homeserver behind your own reverse proxy.

The default layout is delegated:

- user IDs use the apex domain, for example `@alice:example.com`
- Continuwuity itself is reverse-proxied on `matrix.example.com`
- `/.well-known/matrix/client` and `/.well-known/matrix/server` are served by Continuwuity for `example.com`

## Quick start

```shell
cp .env.dist .env
nano -w .env
docker compose up -d
```

## Reverse proxy and host layout

The base stack binds only to `127.0.0.1:${HTTP_BIND_PORT:-6167}` and is suitable for host-level Nginx or Caddy.

If you already run Traefik in Docker, switch to `COMPOSE_VARIANT=traefik` and make sure the external Docker network from `TRAEFIK_NETWORK` exists. The default network name is `traefik`.

For Traefik, `TRAEFIK_MATRIX_HOST` is the main hostname routed to Continuwuity itself. `TRAEFIK_WELL_KNOWN_HOST` is the hostname routed for `/.well-known/matrix/*`.

With the current single-router label set:

- delegated default:
  - `TRAEFIK_MATRIX_HOST=matrix.example.com`
  - `TRAEFIK_WELL_KNOWN_HOST=example.com`
- Matrix subdomain only, for example `matrix.example.com`:
  - `TRAEFIK_MATRIX_HOST=matrix.example.com`
  - `TRAEFIK_WELL_KNOWN_HOST=matrix.example.com`
- apex direct:
  - `TRAEFIK_MATRIX_HOST=example.com`
  - `TRAEFIK_WELL_KNOWN_HOST=example.com`

That keeps the Traefik rule valid without needing a separate `/.well-known` host. The Continuwuity `CONTINUWUITY_WELL_KNOWN__*` variables are separate: they control the discovery responses served by Continuwuity itself and can be commented out when no delegation is needed.

If you hit Docker DNS issues during federation, switch to `COMPOSE_VARIANT=host_resolver` or `traefik_host_resolver` to mount the host `/etc/resolv.conf`, matching the upstream Docker docs.

To change the default delegated layout:

- Matrix subdomain only:
  - set `CONTINUWUITY_SERVER_NAME=matrix.example.com`
  - comment out `CONTINUWUITY_WELL_KNOWN__CLIENT`
  - comment out `CONTINUWUITY_WELL_KNOWN__SERVER`
- Apex domain only:
  - keep `CONTINUWUITY_SERVER_NAME=example.com`
  - comment out `CONTINUWUITY_WELL_KNOWN__CLIENT`
  - comment out `CONTINUWUITY_WELL_KNOWN__SERVER`
  - proxy the apex domain directly to Continuwuity

## First admin user

Bootstrap the first local user with a one-shot command before relying on admin-room commands:

```shell
docker compose run --rm --no-deps continuwuity /sbin/conduwuit --execute "users create-user admin"
```

Use the generated password from the command output to sign in. The first local user is the bootstrap admin path for this stack.

After that, start or restart the regular container:

```shell
docker compose up -d
```

## Registration and invite flow

This stack defaults to token-gated registration managed by admins:

- `CONTINUWUITY_ALLOW_REGISTRATION=true`
- no static registration token in `.env`
- no token file configured by default

This is not open registration: account creation stays enabled, but users still need a valid registration token.

Issue invite tokens from the admin room in your Matrix client:

```text
!admin token issue
!admin token list
!admin token revoke
```

Static token alternatives exist upstream, but this stack treats them as optional fallback methods rather than the default flow.

## Basic post-install settings

- Review your domain settings in `.env` before first real use. `CONTINUWUITY_SERVER_NAME` is effectively permanent once the server has data.
- Keep `CONTINUWUITY_TRUSTED_SERVERS=["matrix.org"]` unless you have a deliberate reason to change key-server behavior.
- Add support metadata with the `CONTINUWUITY_WELL_KNOWN__SUPPORT_*` variables or via TOML later.
- If you raise `CONTINUWUITY_MAX_REQUEST_SIZE`, raise the matching request/body size limit in your reverse proxy too.
- Enable `CONTINUWUITY_DATABASE_BACKUP_PATH` only when you actually want online RocksDB backups created under `./backups`.

## User management

Two concise paths are intended:

- Container CLI bootstrap for the first user:
  - `docker compose run --rm --no-deps continuwuity /sbin/conduwuit --execute "users create-user <name>"`
- Admin room commands afterwards:
  - `!admin users create-user`
  - `!admin users reset-password`
  - `!admin users deactivate`
  - `!admin users suspend`
  - `!admin users unsuspend`
  - `!admin users make-user-admin`

See upstream docs:

- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/reference/admin/users.md
- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/reference/admin/token.md

## Media management

Relevant admin-room commands:

- `!admin media delete`
- `!admin media delete-list`
- `!admin media delete-past-remote-media`
- `!admin media delete-all-from-user`
- `!admin media delete-all-from-server`
- `!admin media delete-url-preview`

Upstream currently stores media under the database directory at `media/`. Separate DB and media paths are not documented as supported yet.

Reference:

- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/reference/admin/media.md
- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/maintenance.mdx

## Server management

Relevant admin-room commands:

- `!admin server show-config`
- `!admin server reload-config`
- `!admin server clear-caches`
- `!admin server backup-database`
- `!admin server list-backups`
- `!admin server restart`
- `!admin server shutdown`

Online backups are RocksDB-only. Media backup is still copying the `media/` subtree from your data directory.

Reference:

- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/reference/admin/server.md
- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/maintenance.mdx

## Other admin commands

- Integrity checks: `!admin check check-all-users`
- Appservices: `!admin appservices register`, `unregister`, `list-registered`
- Rooms: `!admin rooms list-rooms`, `info`, `moderation`, `alias`, `directory`

Reference:

- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/reference/admin/check.md
- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/reference/admin/appservices.md
- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/reference/admin/rooms.md

## Optional TOML configuration

The stack is env-first, but `./config` is already mounted into `/etc/continuwuity`.

To migrate selected settings into TOML later:

1. Copy `config/continuwuity.toml.dist` to `config/continuwuity.toml`.
2. Set `CONTINUWUITY_CONFIG=/etc/continuwuity/continuwuity.toml` in `.env`.
3. Move the settings you want into TOML.
4. Comment out the equivalent env vars instead of keeping the same setting in two places.
5. Restart the service and verify with `!admin server show-config`.

Use TOML when you want clearer structure for:

- support metadata
- TURN settings
- MatrixRTC / future LiveKit foci
- backup path

## Calls and TURN

This stack does not include LiveKit or coturn.

It does avoid blocking them later:

- `config/continuwuity.toml.dist` includes commented TURN and MatrixRTC sections
- the delegated default works with a future separate LiveKit domain

Upstream references:

- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/calls/livekit.mdx
- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/calls/turn.mdx
