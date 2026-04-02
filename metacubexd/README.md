# MetaCubeXD

[MetaCubeXD](https://github.com/MetaCubeX/metacubexd) is the official Mihomo web dashboard. It can be used with one default backend or with multiple Mihomo controllers added from the browser.

## Quick start

```shell
cp .env.dist .env
nano -w .env
docker compose up -d
```

## Backend URLs

`DEFAULT_BACKEND_URL` is optional.

- Leave it unset if you want to pick or add Mihomo backends manually in the browser.
- Set it to a browser-reachable Mihomo controller URL if you want the UI to open with one default backend already selected.

Publishing only the dashboard is not enough for remote management. The browser must also be able to reach the Mihomo controller URL that you configure.

## Traefik

To publish MetaCubeXD through Traefik, set `COMPOSE_VARIANT=traefik` in `.env` and make sure the external Docker network from `TRAEFIK_NETWORK` exists. The default shared network name is `traefik`.

Set `TRAEFIK_HOST` to the hostname you want Traefik to serve for MetaCubeXD. By default the router uses the `websecure` entrypoint and relies on Traefik's entrypoint-level TLS and certificate resolver defaults.

For general setup instructions, please refer to the [root README](../README.md).
