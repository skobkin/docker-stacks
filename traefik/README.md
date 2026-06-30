# Traefik

This stack runs [Traefik](https://traefik.io/traefik/) as a shared Docker reverse proxy for stacks in this repository.

For a gradual migration where host Nginx keeps `:80` and `:443` and forwards everything not explicitly handled there to Traefik, see [NGINX.md](./NGINX.md).

It uses:

- the Docker provider for stack labels
- the file provider for reusable middlewares and transports
- automatic TLS via Let's Encrypt
- a Docker socket proxy sidecar instead of mounting the raw Docker socket into Traefik

## Prerequisites

This stack requires the external `traefik` Docker network. Create it before first start:

```shell
docker network create traefik
```

Reference:

- [shared Traefik network guide](../_docs/traefik_network.md)

## Quick start

```shell
cp .env.dist .env
nano -w .env
install -d data/acme secrets
cp config/dynamic/dashboard.yml.dist config/dynamic/dashboard.yml
cp config/dynamic/shared.yml.dist config/dynamic/shared.yml
cp config/dynamic/default-access.yml.dist config/dynamic/default-access.yml
install -m 600 /dev/null data/acme/acme.json
docker run --rm httpd:2.4-alpine htpasswd -nbB admin 'change-me' > secrets/dashboard.htpasswd
docker compose up -d
```

Before starting Traefik, edit `config/dynamic/default-access.yml` and keep exactly one `default-access` definition uncommented. The dashboard will then be available on the host name from `TRAEFIK_DASHBOARD_HOST`, over HTTPS on `HTTPS_BIND_PORT`.

## Most important settings

- `TRAEFIK_DASHBOARD_HOST`: dashboard/API host name.
- `TRAEFIK_DASHBOARD_MIDDLEWARES`: dashboard middleware list, defaulting to `default-access@file,dashboard-chain@file`.
- `TRAEFIK_CERTIFICATESRESOLVERS_DEFAULT_ACME_EMAIL`: email used for Let's Encrypt registration and expiry notices.
- `HTTP_BIND_PORT` and `HTTPS_BIND_PORT`: change these if you need to run Traefik beside another web server during migration or testing.
- `HTTPS_UDP_BIND_PORT`: UDP host port for HTTP/3 on the `websecure` entrypoint, defaulting to `443`.
- `MATRIX_FEDERATION_BIND_PORT`: optional Matrix federation entrypoint port, defaulting to `8448`.
- `GRPC_BIND_PORT`: optional shared gRPC-over-HTTPS entrypoint port, defaulting to `9443`.
- `STATIC_FILES_PATH`: host directory mounted read-only into Traefik at `/srv/static` for `statiq` static-file routers.
- `TRAEFIK_ENTRYPOINTS_WEB_FORWARDEDHEADERS_TRUSTEDIPS` and `TRAEFIK_ENTRYPOINTS_WEBSECURE_FORWARDEDHEADERS_TRUSTEDIPS`: set these when Traefik is behind another reverse proxy, load balancer, or Cloudflare. Use the published IP ranges of that upstream and do not trust arbitrary sources.
- `TRAEFIK_LOG_LEVEL` and `TRAEFIK_ACCESSLOG`: useful when debugging routing, ACME, or upstream behavior. Access logs are disabled by default.

## Dashboard authentication

Dashboard basic auth is configured through the file provider, not labels, so credentials stay out of Docker metadata. The default dashboard router middleware list is:

```dotenv
TRAEFIK_DASHBOARD_MIDDLEWARES=default-access@file,dashboard-chain@file
```

`dashboard-chain@file` is defined in `config/dynamic/dashboard.yml` and currently contains the `dashboard-auth` Basic auth middleware.

The htpasswd file is expected at:

- `./secrets/dashboard.htpasswd`
- example format: `./secrets/dashboard.htpasswd.dist`

To rotate credentials, overwrite that file and restart Traefik:

```shell
docker run --rm httpd:2.4-alpine htpasswd -nbB admin 'new-password' > secrets/dashboard.htpasswd
docker compose up -d
```

To protect the dashboard with Authelia instead of Basic auth:

1. Copy `config/dynamic/public-access.yml.dist` to `config/dynamic/public-access.yml` (if not already).
2. Run the Authelia stack on the same `traefik` network.
3. Set this in the Traefik stack's Compose interpolation environment, normally `traefik/.env`:

```dotenv
TRAEFIK_DASHBOARD_MIDDLEWARES=public-auth-access@file
```

4. Recreate the Traefik container:

```shell
docker compose up -d traefik
```

The rendered router label must contain only `public-auth-access@file` for the dashboard router. If the browser still shows an HTTP Basic auth prompt, check the rendered Compose config:

```shell
docker compose config | grep 'traefik.http.routers.dashboard.middlewares'
```

## Optional SSO auth for public services

The tracked `config/dynamic/public-access.yml.dist` template includes two middlewares:

- `public-access@file`: allow all IPv4 and IPv6 sources
- `public-auth-access@file`: require Authelia forward-auth through `http://authelia:9091/api/authz/forward-auth`

The `public-auth-access@file` middleware intentionally filters request headers sent to Authelia and does not forward `Authorization`. This keeps normal browser SSO on Authelia's session-cookie flow and avoids stale Basic auth credentials from old dashboard access being interpreted as Authelia header authentication.

To enable the SSO middleware, copy the template to the live file-provider path:

```shell
cp config/dynamic/public-access.yml.dist config/dynamic/public-access.yml
```

Protected stacks can then opt in with:

```dotenv
TRAEFIK_ACCESS_POLICY=public-auth-access@file
```

`TRAEFIK_ACCESS_POLICY` is used by other Traefik-enabled stacks in this repository. The Traefik dashboard router does not read it; use `TRAEFIK_DASHBOARD_MIDDLEWARES` for the dashboard.

Authelia handles SSO and second-factor checks before the request reaches the application. Applications that keep their own login system will usually still show their own login after Authelia succeeds unless they explicitly support trusting Authelia's forwarded identity headers.

## Optional AI-bot firewall

The tracked `config/dynamic/anubis.yml.dist` template defines three objects:

- `anubis@file` (middleware): forward-auth to the [Anubis](https://anubis.techaro.lol/) AI-bot firewall at `http://anubis:8923/.within.website/x/cmd/anubis/api/check`
- `anubis@file` (service): the Anubis upstream on the shared `traefik` network
- `anubis-static` (router): a low-priority catch-all router that serves the Anubis challenge page and its static assets on every host under `PathPrefix("/.within.website/")` on `websecure`

Anubis is a proof-of-work challenge that issues a small challenge to suspicious clients before they reach the application. It is shared across stacks: the operator runs the Anubis stack on the same `traefik` network and opts individual stacks into the middleware.

The default flow is **in-site**: Anubis is not exposed on a public hostname of its own. The challenge is served on the same host as the protected application, with relative URLs in the challenge HTML that resolve to the protected host the user is actually on. A single Anubis instance therefore works for an arbitrary number of protected hosts (`forgejo.example.com`, `woodpecker.example.com`, ...) without per-host config. Each protected host is its own origin from the cookie's perspective, so the user solves the challenge once per host — by design, to keep the cookie scoped to a single origin.

To enable it:

1. Run the Anubis stack on the same external `traefik` network.
2. Copy the template to the live file-provider path:

    ```shell
    cp config/dynamic/anubis.yml.dist config/dynamic/anubis.yml
    ```

3. In the target stack's `.env`, append `anubis@file` to the existing `TRAEFIK_ACCESS_POLICY`:

    ```dotenv
    TRAEFIK_ACCESS_POLICY=default-access@file,anubis@file
    ```

    The order in the comma-separated list is the order the middlewares run, and all of them run on every request that reaches the router. `default-access@file` is an `ipAllowList`; when it returns 403, Anubis is never consulted. For requests that pass the allow list, Anubis runs next and either allows the request through or returns 401 with the challenge page. The Anubis 401 body is HTML that references same-origin assets under `/.within.website/`; the `anubis-static` catch-all router in the same file-provider config serves those assets from the Anubis service on every host that has Anubis in its access policy.

For per-stack path exemption (for example webhook receivers or ACME HTTP-01 challenges), edit the Anubis policy file. The full step-by-step guide, including the **Advanced: Anubis on a separate public host** section that describes a future `traefik_exposed` variant and the variables it would require, lives in the [Anubis stack README](../anubis/README.md).

## Optional mutual-TLS (client certificate) auth

Mutual TLS authenticates a client by requiring it to present a certificate signed by a CA you control. In Traefik this is enforced at the **TLS handshake** via a `tls.options` `clientAuth` setting, not as an HTTP middleware, so the cert is checked before any request (or HTTP middleware like `default-access@file`) runs.

This means mTLS **cannot be applied conditionally by source IP on a single hostname**: by the time an `ipAllowList` middleware sees the client IP, the cert has already been demanded. The supported way to get "LAN-friendly on one port, cert-gated on another" is a **dedicated mTLS entrypoint on a separate port**. A service keeps its normal LAN-only `:443` router and adds a second router on the mTLS port that is reachable from the WAN only with a valid client certificate.

> Requires Traefik **>= 3.7.5**. The same hostname served on two entrypoints with different `tls.options` was broken by a regression in v3.7.3/v3.7.4 (upstream [#13314](https://github.com/traefik/traefik/issues/13314), fixed in [#13329](https://github.com/traefik/traefik/pull/13329)), which silently dropped mTLS. The rolling `IMAGE_TAG=v3` is currently safe (>= 3.7.6). After enabling mTLS, watch the logs for `Found different TLS options for routers on the same host` - if it appears, mTLS is silently off (bad/old image) and must not be trusted.

The tracked `config/dynamic/mtls.yml.dist` template defines three objects:

- `mtls@file` (TLS option): strict - `RequireAndVerifyClientCert`. The handshake fails for any client without a valid cert. Best for API / automated / service-to-service clients.
- `mtls-optional@file` (TLS option): soft - `VerifyClientCertIfGiven`. Verifies a cert if one is sent but does not require one. Useful during gradual rollout or as an extra identity channel on top of Authelia. Does not authenticate by itself; pair it with forward-auth or basic-auth.
- `forward-client-cert@file` (HTTP middleware): `passTLSClientCert` that relays the presented cert to the backend in headers, so the backend can do its own authorization. This does **not** enforce verification; layer it on top of `mtls@file`, not in place of it.

To enable it:

1. Copy the template to the live file-provider path:

    ```shell
    cp config/dynamic/mtls.yml.dist config/dynamic/mtls.yml
    ```

2. Provision a client CA and a client certificate (see [Client certificates](#client-certificates) below).

3. Enable the dedicated `webmtls` entrypoint in `.env` by uncommenting the `TRAEFIK_ENTRYPOINTS_WEBMTLS_*` block. Its `TLS_OPTIONS=mtls@file` makes every router on that entrypoint require a client cert. Publish the port (`MTLS_BIND_PORT`, default `10443`) and open it on the host firewall for WAN access.

4. Recreate Traefik:

    ```shell
    docker compose up -d
    ```

A service then opts in with a **second router** on `webmtls`, leaving its LAN-only `:443` router untouched:

```yaml
    labels:
      # Existing LAN-only router on :443 - default-access@file blocks everyone
      # outside the trusted subnet. Unchanged.
      traefik.http.routers.home-assistant.rule: "Host(`${TRAEFIK_HOST}`)"
      traefik.http.routers.home-assistant.entrypoints: "websecure"
      traefik.http.routers.home-assistant.middlewares: "${TRAEFIK_ACCESS_POLICY:-default-access@file}"

      # New WAN-reachable router on the mTLS port. The client cert is required by
      # the entrypoint's tls.options=mtls@file, so no per-router tls.options label.
      traefik.http.routers.home-assistant-mtls.rule: "Host(`${TRAEFIK_HOST}`)"
      traefik.http.routers.home-assistant-mtls.entrypoints: "webmtls"
      traefik.http.routers.home-assistant-mtls.service: "home-assistant"
      # Optional: forward the cert to the backend for its own authorization.
      traefik.http.routers.home-assistant-mtls.middlewares: "forward-client-cert@file"
```

ACME HTTP-01 is unaffected: it runs on the plaintext `web` entrypoint. The `webmtls` router gets its Let's Encrypt server certificate from the same `default` certresolver; `tls.options` only adds the client-certificate requirement.

### Client certificates

There is no PKI in this repository. Create a local CA and client certificates under the gitignored `secrets/mtls/` tree:

```shell
install -d secrets/mtls/clients

# Local CA (keep ca.key offline after signing clients)
openssl genrsa -out secrets/mtls/ca.key 4096
openssl req -x509 -new -nodes -key secrets/mtls/ca.key -sha256 -days 3650 \
  -subj "/CN=docker-stacks local client CA" -out secrets/mtls/ca.crt
chmod 600 secrets/mtls/ca.key

# The file the template references as caFiles
cp secrets/mtls/ca.crt secrets/mtls/client-ca.crt

# A client certificate
openssl genrsa -out secrets/mtls/clients/alice.key 2048
openssl req -new -key secrets/mtls/clients/alice.key -subj "/CN=alice" \
  -out secrets/mtls/clients/alice.csr
openssl x509 -req -in secrets/mtls/clients/alice.csr \
  -CA secrets/mtls/ca.crt -CAkey secrets/mtls/ca.key -CAcreateserial \
  -days 825 -sha256 -out secrets/mtls/clients/alice.crt
```

Present a client certificate with curl:

```shell
curl --cert secrets/mtls/clients/alice.crt \
     --key  secrets/mtls/clients/alice.key \
     https://home-assistant.example.com:10443/
```

Without a client certificate, the TLS handshake fails (no HTTP response at all), which is the expected behavior of `RequireAndVerifyClientCert`.

Traefik does not reliably prompt browsers for a client certificate (upstream [#10643](https://github.com/traefik/traefik/issues/10643)), and OS-level browser cert selection often sends nothing and produces a confusing handshake failure. mTLS here is therefore best suited to **API, automated, and service-to-service clients** that present a certificate through tooling. For human/browser-facing endpoints, prefer Authelia (`public-auth-access@file`) or the Anubis challenge.

## Certificates

This stack defaults to:

- `web` on port `80`
- `websecure` on port `443`
- HTTP/3 on `websecure` via UDP port `443`
- `matrixfederation` on port `8448`
- `grpcsecure` on port `9443`
- automatic HTTP to HTTPS redirect
- a default `websecure` certresolver named `default`

Because the certresolver is attached to TLS entrypoints, most proxied services do not need their own `tls.certresolver` label.

HTTP/3 is enabled for routers that use the TLS-enabled `websecure` entrypoint. The host firewall and any upstream network firewall must allow UDP traffic to `HTTPS_UDP_BIND_PORT`. If the public UDP port differs from Traefik's internal `:443` entrypoint, set `TRAEFIK_ENTRYPOINTS_WEBSECURE_HTTP3_ADVERTISEDPORT` so clients receive the correct `alt-svc` port.

`acme.json` is stored under `./data/acme/acme.json` and should stay private with mode `600`.

For wildcard certificates or DNS-based validation later, switch from the default HTTP-01 settings in `.env` to Traefik's DNS challenge variables. The stack keeps that path open and does not hard-code a provider.

## Access logs

Traefik access logs are disabled by default. To enable them, uncomment this in `.env`:

```dotenv
TRAEFIK_ACCESSLOG=true
```

Without `TRAEFIK_ACCESSLOG_FILEPATH`, Traefik writes access logs to stdout, so Docker stores them together with the regular Traefik container logs. Retention is size/count based through the existing Docker log settings:

```dotenv
LOG_MAX_SIZE=5m
LOG_MAX_FILE=5
```

That keeps roughly `LOG_MAX_SIZE * LOG_MAX_FILE` of combined Traefik logs for the container. You can also use Traefik's optional access-log settings, for example:

```dotenv
TRAEFIK_ACCESSLOG_FORMAT=json
TRAEFIK_ACCESSLOG_BUFFERINGSIZE=100
```

Avoid setting `TRAEFIK_ACCESSLOG_FILEPATH` unless you also configure host log rotation for that file. Docker's `json-file` limits only apply to stdout/stderr container logs, not to files Traefik writes inside a mounted directory.

## Tracked templates vs local files

This stack keeps example templates in Git and ignores the live local copies you actually edit:

- `config/dynamic/*.yml.dist`: tracked examples
- `config/dynamic/*.yml`: live file-provider config, ignored by Git
- `secrets/*.dist`: tracked examples
- `secrets/*`: live secret files, ignored by Git

Before first start, copy `dashboard.yml.dist`, `shared.yml.dist`, and `default-access.yml.dist` from `.dist` to `.yml`. Copy `public-access.yml.dist` only when you intentionally use `TRAEFIK_ACCESS_POLICY=public-access@file`, `TRAEFIK_ACCESS_POLICY=public-auth-access@file`, or `TRAEFIK_DASHBOARD_MIDDLEWARES=public-auth-access@file`. Copy `anubis.yml.dist` only when you intentionally run the Anubis stack and want to opt stacks into `anubis@file`. Copy `unknown-host-redirect.yml.dist` only when you want unmatched hostnames to redirect to a canonical URL. Copy `mtls.yml.dist` only when you intentionally enable mutual-TLS client-certificate auth and have placed a client CA at `secrets/mtls/client-ca.crt`. For the dashboard password file, generate a real `dashboard.htpasswd` instead of reusing the example.

## Reusable file-provider config

The whole `./config` directory is mounted into `/etc/traefik`, and the file provider watches:

- `/etc/traefik/dynamic`

Included reusable objects:

- `default-access@file`: default access policy middleware that every Traefik-enabled stack router uses unless overridden
- `public-access@file`: optional all-sources access policy for stacks that set `TRAEFIK_ACCESS_POLICY=public-access@file`
- `public-auth-access@file`: optional Authelia forward-auth policy for stacks that set `TRAEFIK_ACCESS_POLICY=public-auth-access@file`
- `anubis@file`: optional Anubis forward-auth policy and `anubis-static` low-priority catch-all router that serves the Anubis challenge assets on every host under `PathPrefix("/.within.website/")`; both load when stacks set `TRAEFIK_ACCESS_POLICY=...anubis@file` and run the Anubis stack on the shared `traefik` network
- `unknown-host-redirect@file`: optional catch-all redirect router and middleware for hostnames not matched by more specific routers
- `mtls@file` / `mtls-optional@file`: optional mutual-TLS `tls.options` (strict / soft client-certificate verification), plus `forward-client-cert@file`: middleware that relays a presented client cert to the backend; all load when you copy `mtls.yml.dist` to `mtls.yml` — see [Optional mutual-TLS auth](#optional-mutual-tls-client-certificate-auth)
- `dashboard-chain@file`: dashboard auth chain
- `chain-default@file`: light shared middleware chain
- `redirect-to-https@file`: shared router-level HTTP to HTTPS redirect middleware
- `upload-50m@file`
- `upload-250m@file`
- `long-lived@file`

The tracked templates live in:

- `config/dynamic/dashboard.yml.dist`
- `config/dynamic/default-access.yml.dist`
- `config/dynamic/public-access.yml.dist`
- `config/dynamic/anubis.yml.dist`
- `config/dynamic/shared.yml.dist`
- `config/dynamic/static-files.yml.dist`
- `config/dynamic/unknown-host-redirect.yml.dist`
- `config/dynamic/mtls.yml.dist`

Typical uses:

- default stack access policy: copy `default-access.yml.dist` to `default-access.yml` and choose the private or public definition
- public single-stack override: copy `public-access.yml.dist` to `public-access.yml`, then set `TRAEFIK_ACCESS_POLICY=public-access@file` in that stack
- SSO single-stack override: run the Authelia stack, copy `public-access.yml.dist` to `public-access.yml`, then set `TRAEFIK_ACCESS_POLICY=public-auth-access@file` in that stack
- AI-bot firewall: run the Anubis stack on the `traefik` network, copy `anubis.yml.dist` to `anubis.yml`, then set `TRAEFIK_ACCESS_POLICY=default-access@file,anubis@file` (or another access policy followed by `,anubis@file`) in the target stack
- unmatched host redirect: copy `unknown-host-redirect.yml.dist` to `unknown-host-redirect.yml`, then replace `https://traefik.example.com/` with the canonical URL for requests whose host does not match any stack or dynamic router
- mutual-TLS client-cert auth: copy `mtls.yml.dist` to `mtls.yml`, place a client CA at `secrets/mtls/client-ca.crt`, enable the `webmtls` entrypoint, then add a second router on that entrypoint to the stack that needs WAN access — see [Optional mutual-TLS auth](#optional-mutual-tls-client-certificate-auth)
- router-level HTTPS redirect: add `redirect-to-https@file` to routers that should redirect plain HTTP requests to HTTPS
- larger uploads: add `upload-250m@file` to the router middleware list
- common compression: add `chain-default@file`
- long-lived or streaming backends: set `traefik.http.services.<name>.loadbalancer.serversTransport=long-lived@file`

WebSocket upgrades do not need a dedicated Traefik switch. Normal HTTP routers work as long as the backend itself supports them.

## Serving static files

Static file catalogs use the `statiq` plugin through Traefik's file provider.

`STATIC_FILES_PATH` from `.env` is mounted read-only into the Traefik container at `/srv/static`. By default, this is `./static` inside this stack directory.

Create one subdirectory per public catalog host:

```shell
install -d static/f.example.com
install -d static/i.example.com
```

Put the files for each catalog into its matching subdirectory. For example, files under `./static/f.example.com` are served by a router whose `statiq.root` is `/srv/static/f.example.com`.

Use `config/dynamic/static-files.yml.dist` as the starting point for each catalog:

```shell
cp config/dynamic/static-files.yml.dist config/dynamic/f.example.com.yml
```

Then edit the live `.yml` file and change:

- router and middleware names, so they are unique
- `rule`, to match the public host names
- `root`, to match the catalog subdirectory under `/srv/static`

## Adding another stack behind Traefik

The proxied stack should:

1. join the same external Docker network
2. set `traefik.enable=true`
3. set `traefik.docker.network=${TRAEFIK_NETWORK}`
4. define router rule, entrypoint, TLS, and backend port labels

Minimal example:

```yaml
services:
  app:
    networks:
      - default
      - traefik
    labels:
      traefik.enable: "true"
      traefik.docker.network: "${TRAEFIK_NETWORK:-traefik}"
      traefik.http.routers.app.rule: "Host(`app.example.com`)"
      traefik.http.routers.app.entrypoints: "websecure"
      traefik.http.routers.app.middlewares: "${TRAEFIK_ACCESS_POLICY:-default-access@file},chain-default@file"
      traefik.http.services.app.loadbalancer.server.port: "8080"

networks:
  traefik:
    external: true
    name: "${TRAEFIK_NETWORK:-traefik}"
```

Add service-specific extras only when needed:

- uploads: `...,upload-250m@file`
- long-lived upstreams: `traefik.http.services.app.loadbalancer.serversTransport=long-lived@file`
- WAN access with a client certificate: add a second router on the `webmtls` entrypoint (see [Optional mutual-TLS auth](#optional-mutual-tls-client-certificate-auth))

For shared Traefik usage across stacks in this repository, see [Common Traefik Usage](../_docs/traefik.md).

## Docker socket compromise

This stack uses a socket-proxy sidecar as the default compromise:

- Traefik still gets Docker discovery
- the raw Docker socket is not mounted into Traefik itself
- only the Docker API sections needed for discovery are allowed
- write operations stay disabled with `POST=0`

This is still not the same as a fully isolated control plane. Anyone who can fully compromise Traefik or the socket-proxy network path may still gain sensitive visibility into Docker metadata. For a small personal VPS or home lab, this is a reasonable middle ground between safety and operational simplicity.

## Advanced docs

- Docker provider: https://doc.traefik.io/traefik/reference/install-configuration/providers/docker/
- File provider: https://doc.traefik.io/traefik/reference/install-configuration/providers/others/file/
- API and dashboard: https://doc.traefik.io/traefik/reference/install-configuration/api-dashboard/
- EntryPoints: https://doc.traefik.io/traefik/reference/install-configuration/entrypoints/
- HTTP/3 entrypoint settings: https://doc.traefik.io/traefik/routing/entrypoints/#http3
- Logs and access logs: https://doc.traefik.io/traefik/reference/install-configuration/observability/logs-and-accesslogs/
- ACME: https://doc.traefik.io/traefik/reference/install-configuration/tls/certificate-resolvers/acme/
- Middlewares: https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/overview/
