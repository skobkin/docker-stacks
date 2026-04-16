# Mihomo

This stack replaces `v2fly-client` with [Mihomo](https://github.com/MetaCubeX/mihomo) while keeping the same default SOCKS, HTTP, and TProxy host ports.

## Prerequisites

This service requires the `proxy` Docker network. Please follow the [network configuration guide](../_docs/proxy_network.md) before starting the service.

## Quick start

```shell
cp .env.dist .env
cp config/config.yaml.dist config/config.yaml.tmpl
nano -w .env
nano -w config/config.yaml.tmpl
docker compose up -d
```

## Configuration flow

- `config/config.yaml.tmpl` is your local editable Mihomo template.
- `render-config.sh` renders `config/config.yaml` from that template on every container start.
- `.env` controls the published host ports, the rendered listener ports, and the controller secret.
- The shipped template boots with `DIRECT` only. Add your actual outbound proxy definitions before real use.

## Controller security

Mihomo controller authentication uses the upstream `secret` bearer token. This stack refuses to start while `CONTROLLER_SECRET` is left at its sample value.

By default the controller API is published only to `127.0.0.1:${CONTROLLER_HOST_PORT:-9092}`.

## Traefik

Set `COMPOSE_VARIANT=traefik` in `.env` to publish the controller API through Traefik. This variant exposes only the Mihomo controller HTTP API, not the proxy listener ports.

If you publish the controller outside localhost:

- use TLS
- keep a strong `CONTROLLER_SECRET`
- prefer extra proxy-level protections such as IP allowlisting or additional auth

## TProxy

This stack preserves the current TProxy listener port, but host routing, firewall, and policy-routing rules remain your responsibility outside Docker.

For general setup instructions, please refer to the [root README](../README.md).
