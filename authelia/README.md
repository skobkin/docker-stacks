# Authelia

This stack runs [Authelia](https://www.authelia.com/) as an SSO portal and Traefik forward-auth provider.

It defaults to:

- Authelia on `127.0.0.1:${HTTP_BIND_PORT:-9091}`
- optional Traefik exposure on `TRAEFIK_HOST`
- local SQLite storage under `./data/db.sqlite3`
- file-backed users in `./config/users_database.yml`
- password plus one second factor for protected services
- TOTP and WebAuthn second factors, with passkey login disabled by default

## Quick start

```shell
cp .env.dist .env
cp config/configuration.yml.dist config/configuration.yml
cp config/users_database.yml.dist config/users_database.yml
install -d data secrets
docker run --rm authelia/authelia:4.39 authelia crypto rand --length 64 > secrets/session_secret
docker run --rm authelia/authelia:4.39 authelia crypto rand --length 64 > secrets/storage_encryption_key
docker run --rm authelia/authelia:4.39 authelia crypto rand --length 64 > secrets/jwt_secret
docker run --rm authelia/authelia:4.39 authelia crypto hash generate argon2 --password 'change-me'
nano -w .env config/configuration.yml config/users_database.yml
docker compose up -d
```

Before starting it for real:

- set `session.cookies[].authelia_url`, usually `https://auth.sub.domain.tld`
- set `TRAEFIK_HOST` to the Authelia portal host, usually `auth.sub.domain.tld`
- set `totp.issuer`, `session.cookies[].domain`, and `access_control.rules[].domain` to the shared parent domain, such as `sub.domain.tld`
- replace the example admin password hash and email in `config/users_database.yml`
- configure a real SMTP notifier path

The example password hash is only a placeholder for local validation. Do not use it in production.

## Passkey login modes

The default `policy: two_factor` rule keeps protected services behind password plus one registered second factor, such as TOTP or WebAuthn. In this mode, passkeys and hardware security keys are available as WebAuthn second factors after password login.

To add passwordless passkey login at the Authelia portal, change this in `config/configuration.yml`:

```yaml
webauthn:
  enable_passkey_login: true
```

Authelia still treats that passkey login as one factor by default. For services protected by `two_factor`, Authelia may still ask for the password after passkey login so the access policy is satisfied.

Authelia also has an experimental mode where user-verified passkeys can satisfy `two_factor` while password plus TOTP/WebAuthn remains valid:

```yaml
webauthn:
  enable_passkey_login: true
  experimental_enable_passkey_uv_two_factors: true
```

Only enable the experimental mode after testing your authenticators and clients. Upstream behavior may change or fail in a future Authelia release. The template also includes a commented stricter WebAuthn metadata/filtering example for operators who want stronger device validation; it is disabled by default because it may reject synced or backup-eligible platform passkeys.

## Traefik forward auth

Authelia's own portal router intentionally has no Authelia middleware. Protected services opt in by setting:

```dotenv
TRAEFIK_ACCESS_POLICY=public-auth-access@file
```

Copy `../traefik/config/dynamic/public-access.yml.dist` to `../traefik/config/dynamic/public-access.yml` in the Traefik stack first, then reload Traefik. The `public-auth-access@file` middleware calls Authelia at `http://authelia:9091/api/authz/forward-auth`, so both Authelia and Traefik must share the external `traefik` network.

Applications with their own login page will still show their own login after Authelia succeeds unless the application also supports trusting Authelia's forwarded headers.

To skip Authelia login for trusted LAN or VPN clients, uncomment the optional `policy: bypass` rule in `config/configuration.yml` and replace the example subnet list. Keep that bypass rule before the normal wildcard protected-domain rule, because Authelia applies the first matching access-control rule.

## Optional Redis sessions

SQLite stores Authelia account, TOTP, WebAuthn, and other persistent data. Redis is optional and only moves session state out of Authelia memory.

To use the shared Redis stack:

1. create the external `databases` network if it does not exist
2. start the `redis` stack with `DATABASES_NETWORK=databases`
3. set `COMPOSE_VARIANT=traefik_databases` or `COMPOSE_VARIANT=databases`
4. uncomment the `session.redis` block in `config/configuration.yml`
5. set `AUTHELIA_SESSION_REDIS_PASSWORD_FILE=/secrets/redis_password` in `.env` if Redis requires a password stored in `secrets/redis_password`

The Redis host is `redis:6379` on the shared network by default.

## ntfy via SMTP

Authelia supports SMTP and filesystem notifications, not native ntfy publishing.

For ntfy notifications, enable ntfy's SMTP publishing listener on a shared Docker network, for example `NTFY_SMTP_SERVER_LISTEN=:2525`, attach both stacks to that network, and set this in `config/configuration.yml`:

```yaml
notifier:
  smtp:
    address: smtp://ntfy:2525
```

That path is plaintext SMTP on the Docker network unless you configure a TLS-capable SMTP relay.

## References

- [Authelia Docker deployment](https://www.authelia.com/integration/deployment/docker/)
- [Authelia Traefik integration](https://www.authelia.com/integration/proxies/traefik/)
- [Authelia session configuration](https://www.authelia.com/configuration/session/introduction/)
- [Authelia file users](https://www.authelia.com/configuration/first-factor/file/)
- [Authelia WebAuthn configuration](https://www.authelia.com/configuration/second-factor/webauthn/)
- [Authelia passkey guide](https://www.authelia.com/reference/guides/webauthn/)
