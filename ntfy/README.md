# ntfy

This stack runs [`ntfy`](https://ntfy.sh), a simple HTTP pub/sub notification service with a web UI, API, and browser/mobile subscriptions.

It defaults to:

- localhost binding on `127.0.0.1:${HTTP_BIND_PORT:-8405}`
- SQLite-backed auth in `./data/user.db`
- persistent message cache in `./data/cache/cache.db`
- private-by-default access (`NTFY_AUTH_DEFAULT_ACCESS=deny-all`)
- signup disabled and web/API login enabled

## Quick start

```shell
cp .env.dist .env
docker compose up -d
```

Edit `.env` before real use, especially:

- `NTFY_BASE_URL`
- `TRAEFIK_HOST` if you plan to use Traefik
- `HOST_UID` / `HOST_GID` if `1000:1000` does not match your host user

## First admin user

The stack enables authentication, but it does not provision users declaratively. Create the first admin user from the container:

```shell
docker compose exec ntfy ntfy user add --role=admin admin
```

Grant topic access to non-admin users as needed:

```shell
docker compose exec ntfy ntfy access someuser alerts rw
docker compose exec ntfy ntfy access someuser backups ro
docker compose exec ntfy ntfy access everyone announcements ro
```

Useful inspection commands:

```shell
docker compose exec ntfy ntfy user list
docker compose exec ntfy ntfy access
docker compose exec ntfy ntfy token add admin
```

## Limited notifier user

For services that only need to publish messages, create a separate non-admin user and grant it write-only access to a topic prefix:

```shell
docker compose exec ntfy ntfy user add user-notify
docker compose exec ntfy ntfy access user-notify 'user-*' write-only
docker compose exec ntfy ntfy access user-notify
```

This keeps the account limited to publishing on `user-*` topics while everything else stays denied by default.

For clients that use basic auth, publish with that dedicated username and password:

```shell
curl -u user-notify:YOUR_PASSWORD \
  -d "test from curl" \
  https://ntfy.example.com/user-test
```

For Shoutrrr-based clients such as Watchtower or Beszel, token auth also works with an empty username and the access token in the password position:

```text
ntfy://:tk_your_token_here@ntfy.example.com/user-watchtower
```

That is separate from the limited-user pattern above, which is still useful when you want a dedicated notifier account with narrow topic ACLs instead of reusing an admin token.

## Reverse proxy and Traefik

The default stack is already suitable for a host-level reverse proxy because it only binds to localhost.

See the [common Traefik guide](../_docs/traefik.md).

This stack assumes one public hostname for the full UI/API surface. Keep these aligned:

- `TRAEFIK_HOST=ntfy.example.com`
- `NTFY_BASE_URL=https://ntfy.example.com`

The Traefik variant also enables `NTFY_BEHIND_PROXY=true`, matching upstream guidance so ntfy uses forwarded client IPs for rate limiting.

Subscriptions use long-lived streaming connections, including websocket transport in the web app. Keep them on the same Traefik router/hostname as the rest of the ntfy UI and API, and avoid proxy settings or middlewares that break `Upgrade` handling or aggressively time out idle connections.

## Optional features

### Web Push for browsers

Generate VAPID keys and then copy them into `.env`:

```shell
docker compose run --rm ntfy webpush keys
```

Then enable:

- `NTFY_WEB_PUSH_PUBLIC_KEY`
- `NTFY_WEB_PUSH_PRIVATE_KEY`
- `NTFY_WEB_PUSH_FILE`
- `NTFY_WEB_PUSH_EMAIL_ADDRESS`

### Attachments

Attachment support is disabled by default. To enable it, set:

- `NTFY_ATTACHMENT_CACHE_DIR`
- optionally the attachment size/expiry limits

This requires a correct public `NTFY_BASE_URL`, because ntfy generates public attachment URLs from it.

### SMTP notifications

SMTP forwarding via the `X-Email` header is disabled by default. Fill in the `NTFY_SMTP_SENDER_*` variables in `.env` if you want ntfy to send mail.

### iOS instant notifications

`NTFY_UPSTREAM_BASE_URL` stays commented by default, so this stack does not forward poll requests upstream. If you enable it, ntfy will forward iOS poll requests to `ntfy.sh` or another upstream service as described in the upstream docs.

## References

- [Docker install docs](https://docs.ntfy.sh/install/)
- [Configuration reference](https://docs.ntfy.sh/config/)
- [Configurator](https://docs.ntfy.sh/config/)
