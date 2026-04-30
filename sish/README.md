# sish

## Optional Traefik

Set `COMPOSE_VARIANT=traefik` and configure `TRAEFIK_HOST_REGEXP` to match the wildcard tunnel hosts.
The Traefik variant only proxies wildcard tunnel traffic to the sish HTTP port over the `websecure` entrypoint by default.

The root domain response from older Nginx configs is intentionally not reproduced here.
See the [common Traefik guide](../_docs/traefik.md) for the shared setup.
