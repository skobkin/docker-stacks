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
install -m 600 /dev/null data/acme/acme.json
docker run --rm httpd:2.4-alpine htpasswd -nbB admin 'change-me' > secrets/dashboard.htpasswd
docker compose up -d
```

The dashboard will then be available on the host name from `TRAEFIK_DASHBOARD_HOST`, over HTTPS on `HTTPS_BIND_PORT`.

## Most important settings

- `TRAEFIK_DASHBOARD_HOST`: dashboard/API host name.
- `TRAEFIK_CERTIFICATESRESOLVERS_DEFAULT_ACME_EMAIL`: email used for Let's Encrypt registration and expiry notices.
- `HTTP_BIND_PORT` and `HTTPS_BIND_PORT`: change these if you need to run Traefik beside another web server during migration or testing.
- `MATRIX_FEDERATION_BIND_PORT`: optional Matrix federation entrypoint port, defaulting to `8448`.
- `TRAEFIK_ENTRYPOINTS_WEB_FORWARDEDHEADERS_TRUSTEDIPS` and `TRAEFIK_ENTRYPOINTS_WEBSECURE_FORWARDEDHEADERS_TRUSTEDIPS`: set these when Traefik is behind another reverse proxy, load balancer, or Cloudflare. Use the published IP ranges of that upstream and do not trust arbitrary sources.
- `TRAEFIK_LOG_LEVEL` and `TRAEFIK_ACCESSLOG`: useful when debugging routing, ACME, or upstream behavior.

## Dashboard authentication

Dashboard basic auth is configured through the file provider, not labels, so credentials stay out of Docker metadata.

The htpasswd file is expected at:

- `./secrets/dashboard.htpasswd`
- example format: `./secrets/dashboard.htpasswd.dist`

To rotate credentials, overwrite that file and restart Traefik:

```shell
docker run --rm httpd:2.4-alpine htpasswd -nbB admin 'new-password' > secrets/dashboard.htpasswd
docker compose up -d
```

## Certificates

This stack defaults to:

- `web` on port `80`
- `websecure` on port `443`
- `matrixfederation` on port `8448`
- automatic HTTP to HTTPS redirect
- a default `websecure` certresolver named `default`

Because the certresolver is attached to TLS entrypoints, most proxied services do not need their own `tls.certresolver` label.

`acme.json` is stored under `./data/acme/acme.json` and should stay private with mode `600`.

For wildcard certificates or DNS-based validation later, switch from the default HTTP-01 settings in `.env` to Traefik's DNS challenge variables. The stack keeps that path open and does not hard-code a provider.

## Tracked templates vs local files

This stack keeps example templates in Git and ignores the live local copies you actually edit:

- `config/dynamic/*.yml.dist`: tracked examples
- `config/dynamic/*.yml`: live file-provider config, ignored by Git
- `secrets/*.dist`: tracked examples
- `secrets/*`: live secret files, ignored by Git

Before first start, copy the dynamic config examples from `.dist` to `.yml`. For the dashboard password file, generate a real `dashboard.htpasswd` instead of reusing the example.

## Reusable file-provider config

The whole `./config` directory is mounted into `/etc/traefik`, and the file provider watches:

- `/etc/traefik/dynamic`

Included reusable objects:

- `dashboard-chain@file`: dashboard auth chain
- `chain-default@file`: light shared middleware chain
- `upload-50m@file`
- `upload-250m@file`
- `long-lived@file`

The tracked templates live in:

- `config/dynamic/dashboard.yml.dist`
- `config/dynamic/shared.yml.dist`

Typical uses:

- larger uploads: add `upload-250m@file` to the router middleware list
- common compression: add `chain-default@file`
- long-lived or streaming backends: set `traefik.http.services.<name>.loadbalancer.serversTransport=long-lived@file`

WebSocket upgrades do not need a dedicated Traefik switch. Normal HTTP routers work as long as the backend itself supports them.

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
      traefik.http.routers.app.middlewares: "chain-default@file"
      traefik.http.services.app.loadbalancer.server.port: "8080"

networks:
  traefik:
    external: true
    name: "${TRAEFIK_NETWORK:-traefik}"
```

Add service-specific extras only when needed:

- uploads: `...,upload-250m@file`
- long-lived upstreams: `traefik.http.services.app.loadbalancer.serversTransport=long-lived@file`

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
- ACME: https://doc.traefik.io/traefik/reference/install-configuration/tls/certificate-resolvers/acme/
- Middlewares: https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/overview/
