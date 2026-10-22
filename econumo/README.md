# Econumo

Self-hosted personal finance and budgeting: accounts, budgets, and transactions with an optional built-in MCP server.

A single [distroless](https://github.com/GoogleContainerTools/distroless) container serves the web UI, the API, and the MCP endpoint (`/mcp`) on one port. The image runs as UID/GID 65532 (`nonroot`) and contains no shell.

- [Website](https://econumo.com/)
- [GitHub](https://github.com/econumo/econumo)
- [Self-hosting docs](https://econumo.com/docs/self-hosting/)
- [MCP setup](https://github.com/econumo/econumo/blob/main/docs/mcp-setup.md)

## Setup

```shell
cp .env.dist .env
nano -w .env          # set TRAEFIK_HOST (and ECONUMO_URL, see below)
mkdir -p data/db data/jwt
sudo chown -R 65532:65532 data
docker compose up -d
```

Traefik is the default variant: the app is published at `https://<TRAEFIK_HOST>` through the reverse proxy and no host port is opened (the external `traefik` network must exist, see [_docs/traefik_network.md](../_docs/traefik_network.md)). To run standalone without a reverse proxy instead, set `COMPOSE_VARIANT=default` in `.env` and open `http://127.0.0.1:8421`.

Why the `mkdir` and `chown`: the image runs as distroless `nonroot` (65532) and pre-creates `/app/var/db` inside the image, but the bind mount over `/app/var` shadows that, bind mounts get no Docker copy-on-first-use ownership fixup, and the app does not create the directories itself — it fails at startup with `unable to open database file` until `db/` and `jwt/` exist and are writable by 65532. On first boot the app creates `data/db/db.sqlite` (and puts the JWT keypair into `data/jwt/` when the first token is issued); you can verify the ownership with `ls -l data/db`.

Version note: upstream publishes only exact `vX.Y.Z` image tags plus `latest` and `dev` — there are no rolling `v1`/`v1.6` tags. The default `latest` works with the repository's watchtower stack for automatic updates; see [Upgrading](#upgrading) for the trade-offs. Never use `dev`.

## First user and registration

Registration is enabled by default. Either register through the web UI on the first visit, or create the user from the CLI:

```shell
docker compose exec econumo /app/econumo user:create "Name" user@example.com 'change-me'
```

Then close public registration: set `ECONUMO_ALLOW_REGISTRATION=false` in `.env` and re-apply:

```shell
docker compose up -d
```

There is no admin role in the self-hosted edition: every account has full control of its own data, and users share individual accounts and budgets by invitation (see [Shared access](https://econumo.com/docs/user-guide/shared-access/)).

## CLI administration

The image has no shell, so all management commands run the binary directly:

```shell
docker compose exec econumo /app/econumo <command>
```

Useful commands:

```shell
# Create a user
docker compose exec econumo /app/econumo user:create "Name" user@example.com 'password'

# Change a user's password (also disconnects all their connected MCP apps)
docker compose exec econumo /app/econumo user:change-password user@example.com 'new-password'

# Deactivate / activate a user
docker compose exec econumo /app/econumo user:deactivate user@example.com
docker compose exec econumo /app/econumo user:activate user@example.com
```

Also available: `user:change-email`, `currency:add`, `currency:update-rates`, `jwt:generate` (the JWT keypair is generated automatically on first boot; the command is only for manual rotation). Running the binary with no command prints the full usage for your version.

## MCP access

Econumo serves an MCP endpoint at `/mcp` on the same port as the web UI, using OAuth 2.1 (authorization code with PKCE, dynamic client registration): the client opens a browser, you sign in to Econumo and approve the app — there is no token to copy.

Browser sign-in requires `ECONUMO_URL` to be set to the public **HTTPS origin** of the instance (no path, e.g. `https://econumo.example.com`) — set it in `.env` next to `TRAEFIK_HOST`. The plain `Host()` router of the Traefik variant (the default) passes everything through, including the `/.well-known/*` discovery and `/oauth/*` routes the flow needs.

**Claude Code:**

```shell
claude mcp add --transport http econumo https://econumo.example.com/mcp
```

Then run `/mcp` inside Claude Code, pick `econumo` and choose Authenticate — the browser opens the Econumo approval page. The OAuth credentials are stored by Claude Code in its own config, not in the environment.

**Codex:**

```shell
codex mcp add econumo --url https://econumo.example.com/mcp
codex mcp login econumo
```

`codex mcp login` opens the browser for the approval page; the token is kept in Codex's own auth store.

**Personal access token alternative.** Clients that cannot do the browser flow can use a personal access token instead: create one in Settings → Profile → API tokens and send it as `Authorization: Bearer eco_pat_...` on `/mcp`. This works with or without `ECONUMO_URL`, including against the local URL `http://127.0.0.1:8421/mcp`. The token lives in the agent's config (see [_docs/mcp.md](../_docs/mcp.md) for per-client header configuration).

Revoke connected apps in Settings → Profile → Connected apps.

Caveat: with the Traefik variant, the `default-access@file` access policy is an IP allow-list that rejects clients before they reach Econumo — make sure it permits the networks your non-browser MCP clients and remote OAuth browsers come from.

## Traefik

Traefik is the default variant (`COMPOSE_VARIANT=traefik` in `.env.dist`). Set `TRAEFIK_HOST` and also set `ECONUMO_URL=https://<TRAEFIK_HOST>` (required for MCP browser sign-in and correct links in emails). No host port is published — the stack is reachable only through the reverse proxy, so the external `traefik` network must exist.

See [_docs/traefik.md](../_docs/traefik.md) and [_docs/traefik_network.md](../_docs/traefik_network.md). To opt out and bind a localhost port instead, set `COMPOSE_VARIANT=default`.

## PostgreSQL via the databases network

Econumo runs on SQLite by default; no PostgreSQL container is bundled with this stack. To use a PostgreSQL server connected to the shared `databases` network, set `COMPOSE_VARIANT=traefik_databases` (or `databases` for a localhost-bound setup) and point `DATABASE_URL` at it, e.g.:

```dotenv
DATABASE_URL=postgres://econumo:change-me@postgres:5432/econumo?sslmode=disable
```

See [_docs/databases_network.md](../_docs/databases_network.md).

## Backup and restore

Econumo has no built-in backup mechanism. Always take a backup before upgrading.

SQLite (default):

```shell
docker compose stop econumo
cp -a data /backup/econumo-data-$(date +%F)
cp .env /backup/econumo-env-$(date +%F)
docker compose start econumo
```

The database is `data/db/db.sqlite`; the `data/jwt/` directory holds the JWT keypair — back it up too, or existing login tokens become invalid after a restore. The app does not enable WAL mode, so a copy taken while the container is stopped is consistent. For PostgreSQL, use your usual tooling (e.g. scheduled `pg_dump`) instead.

Restore: stop the container, put the backup back in place, start it again.

For continuous replication to object storage, upstream documents a [Litestream setup](https://econumo.com/docs/self-hosting/backups/) as an advanced option.

## Upgrading

Database migrations run automatically on boot, so **back up first** (see above), then:

```shell
docker compose pull
docker compose up -d
```

With the default `IMAGE_TAG=latest`, watchtower updates the image automatically — which also triggers migrations without a fresh backup, so keep backups on a schedule. To control upgrades manually, pin an exact release in `.env` (e.g. `IMAGE_TAG=v1.6.1`); there are no rolling major-version tags to pin instead. Do not use `dev`.

To roll back a failed upgrade: restore the backup and set `IMAGE_TAG` to the previous `vX.Y.Z` release before starting the container again.

## OIDC (optional)

To add "Sign in with..." via an OpenID Connect provider, set `ECONUMO_URL` and the `ECONUMO_OIDC_*` variables in `.env` (see comments there). Full walkthrough: [OIDC setup](https://github.com/econumo/econumo/blob/main/docs/oidc-setup.md).

## References

- [Self-hosting docs](https://econumo.com/docs/self-hosting/) (backups, CLI commands, multi-currency)
- [Full configuration reference](https://github.com/econumo/econumo/blob/main/.env.example)
- [MCP setup](https://github.com/econumo/econumo/blob/main/docs/mcp-setup.md)
