# Gatus monitoring

## Setup

```shell
cp .env.dist .env
cp config.yaml.dist config.yaml
```

Then edit your configuration.

## Optional Traefik

Set `COMPOSE_VARIANT=traefik` and `TRAEFIK_HOST` to add Traefik labels.
This stack intentionally keeps `network_mode: host` so Gatus can monitor host-reachable services the same way it does without Traefik.

See the [common Traefik guide](../_docs/traefik.md).

## Docs

Check [github.com/TwiN/gatus](https://github.com/TwiN/gatus/blob/master/README.md) for more information.
