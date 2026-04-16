# Configuration

```shell
cp config/config.json.dist config/config.json
```

Then edit your config.json according to your needs. See 
[this](https://github.com/vector-im/element-web/blob/develop/docs/config.md) for more info.

## Traefik

To publish Element Web through Traefik, set `COMPOSE_VARIANT=traefik` in `.env` and make sure the external Docker network from `TRAEFIK_NETWORK` exists. The default shared network name is `traefik`.

Set `TRAEFIK_HOST` to the hostname you want Traefik to serve for Element Web. By default the router uses the `websecure` entrypoint and relies on Traefik's entrypoint-level TLS and certificate resolver defaults.
