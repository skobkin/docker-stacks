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

See the [common Traefik guide](../_docs/traefik.md).

For general setup instructions, please refer to the [root README](../README.md).
