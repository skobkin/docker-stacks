# Fluent Bit

Log collector that tails Docker's per-container `json-file` log files
and ships them to [VictoriaLogs](../victoria-logs) over HTTP. Picks up
logs from **every container on the host** automatically — no changes to
other stacks required.

- Image: [`fluent/fluent-bit`](https://hub.docker.com/r/fluent/fluent-bit)
- Docs: <https://docs.fluentbit.io/>

## Quick start (same host as VictoriaLogs)

```shell
cd fluent-bit
cp .env.dist .env
docker compose up -d
docker compose logs -f
```

With the default `COMPOSE_VARIANT=default`, fluent-bit joins the
external [`logging`](../_docs/logging_network.md) network and reaches
VictoriaLogs via Docker DNS at `victoria-logs:9428`.

Make sure the [`victoria-logs`](../victoria-logs) stack is running first
— fluent-bit depends on it for a destination.

## Quick start (different host)

To run fluent-bit on a separate host pointing at a remote VictoriaLogs:

1. On the **VictoriaLogs host**, set `VL_BIND_ADDRESS` to a LAN IP
   (e.g. `192.168.1.10`) or `0.0.0.0` in `victoria-logs/.env`, and open
   the port in the host firewall.
2. On this **fluent-bit host**:

   ```shell
   cd fluent-bit
   cp .env.dist .env
   # edit .env:
   #   COMPOSE_VARIANT=remote
   #   VL_ADDRESS=192.168.1.10
   #   VL_PORT=9428
   docker compose up -d
   ```

   The `remote` variant skips the `logging` network (which doesn't
   exist on this host) and uses the address from `VL_ADDRESS` directly.

## Configuration

All settings live in `.env`. The most useful ones:

| Variable | Default | Purpose |
|---|---|---|
| `COMPOSE_VARIANT` | `default` | `default` joins the logging network; `remote` skips it. |
| `VL_ADDRESS` | `victoria-logs` | Hostname or IP of VictoriaLogs. Override for remote variant. |
| `VL_PORT` | `9428` | VictoriaLogs HTTP port. |
| `DOCKER_CONTAINERS_PATH` | `/var/lib/docker/containers` | Host directory holding per-container log files. |
| `FB_STATE_PATH` | `./data` | Where fluent-bit keeps its tail position DB. |
| `FLUENT_BIT_UID` | `0` | User inside the container. Root is required to read docker log files. |

## What it reads

Fluent Bit's `tail` input watches
`/var/lib/docker/containers/<id>/<id>-json.log` — the same files Docker
writes when a stack uses the standard `json-file` logging driver. Every
stack in this repo that doesn't override its `logging:` block is picked
up automatically.

The pipeline:

1. **tail** — reads each container log as it's appended.
2. **modify** — promotes `com.docker.compose.service` and
   `com.docker.compose.project` labels (set by Compose on every
   container) to top-level `compose_service` and `compose_project`
   fields, so VictoriaLogs can group them as streams.
3. **http output** — POSTs JSON lines to
   `http://${VL_ADDRESS}:${VL_PORT}/insert/jsonline` with the
   `_stream_fields=compose_service,compose_project,stream` query string
   so VictoriaLogs can index and filter by stack.

The Docker socket is **not** mounted — only the read-only log directory.

## Querying the collected logs

Once logs are in VictoriaLogs, the UI is at
<http://127.0.0.1:9428> on the host running `victoria-logs`. Sample
LogsQL queries:

- `compose_service:traefik` — all logs from the traefik stack
- `_stream:{compose_service="fluent-bit"}` — fluent-bit's own logs
- `_time:5m` — last 5 minutes across all stacks

See the [VictoriaLogs README](../victoria-logs/README.md) for more.