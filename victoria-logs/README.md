# VictoriaLogs

Centralized log storage and viewing. Reads logs from the local filesystem
written by Docker's `json-file` log driver (collected by the companion
[`fluent-bit`](../fluent-bit) stack) and serves them via a built-in web UI
and LogsQL HTTP API.

- Image: [`victoriametrics/victoria-logs`](https://hub.docker.com/r/victoriametrics/victoria-logs)
- Docs: <https://docs.victoriametrics.com/victorialogs/>

## Quick start

```shell
cd victoria-logs
cp .env.dist .env
# edit .env if needed
docker compose up -d
docker compose logs -f
```

Once running, open <http://127.0.0.1:9428> to use the web UI.

By itself, this stack only stores and serves logs. To collect container
logs into VictoriaLogs, deploy the [`fluent-bit`](../fluent-bit) stack on
the same host.

## Prerequisites

- The external [`logging`](../_docs/logging_network.md) Docker network,
  when running fluent-bit on the same host:

  ```shell
  docker network create logging
  ```

## Configuration

All settings live in `.env`. The most useful ones:

| Variable | Default | Purpose |
|---|---|---|
| `VL_BIND_ADDRESS` | `127.0.0.1` | Host interface to bind the UI port. Override to a LAN IP or `0.0.0.0` for remote fluent-bit access. |
| `VL_BIND_PORT` | `9428` | Host port for the UI / HTTP API. |
| `VL_DATA_PATH` | `./data` | Persistent data directory. |
| `VL_RETENTION_PERIOD` | `30d` | How long logs are kept. |
| `VL_MAX_DISK_USAGE` | `50GiB` | Disk cap. Oldest entries are evicted when reached. |

## Traefik variant

To expose the UI through the shared Traefik stack (behind Authelia):

1. Set `COMPOSE_VARIANT=traefik` in `.env`.
2. Set `VL_TRAEFIK_HOST` to the public hostname (e.g. `logs.example.com`).
3. Make sure the [`traefik`](../traefik) and [`authelia`](../authelia) stacks are running.
4. `docker compose up -d`.

The Traefik router uses `default-access@file,authelia@file` middlewares by
default. Adjust via `VL_TRAEFIK_MIDDLEWARES` if you need a different policy.

## Usage

The web UI at `/` lets you run LogsQL queries against stored logs.
Common starting points:

- `compose_service:traefik` — all logs from the traefik stack
- `_stream:{compose_service="traefik",compose_project="traefik"}` — same, using a stream filter
- `_time:5m` — last 5 minutes

For programmatic access, the LogsQL HTTP API lives at `/select/logsql/query`:

```shell
curl -G --data-urlencode 'query=compose_service:traefik' http://127.0.0.1:9428/select/logsql/query
```

## Security

VictoriaLogs has no built-in authentication. The stack trusts the Docker
network as the boundary. The Traefik variant puts the UI behind Authelia
when the stack is exposed publicly; direct `/insert/jsonline` access from
fluent-bit still relies on the network being trusted.

For multi-host setups, override `VL_BIND_ADDRESS` carefully and consider
putting a firewall in front of port 9428. See the
[`fluent-bit` README](../fluent-bit/README.md) for the remote-variant
workflow.