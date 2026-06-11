# WebHook Tester

This stack runs [WebHook Tester](https://github.com/tarampampam/webhook-tester), a self-hosted UI for receiving and inspecting HTTP webhook requests.

It uses the application's filesystem storage driver. Sessions and captured requests are persisted under `${HOST_DATA_DIR:-./data}` and mounted at `/data` in the container. Redis and multi-instance deployments are outside this stack's scope.

## Setup

```shell
cp .env.dist .env
sudo chown 1000:1000 ./data
docker compose up -d
```

The container runs as `${HOST_UID:-1000}:${HOST_GID:-1000}`. If those defaults are not appropriate, set the UID/GID and host data directory in `.env`, then give that user write access to the selected directory before starting the stack.

By default, the UI is available only at `http://127.0.0.1:8414`.

## Application settings

Optional settings in `.env.dist` control session lifetime, stored-request and request-body limits, automatic session creation, the public URL shown by the UI, and application logging. See the [upstream CLI reference](https://github.com/tarampampam/webhook-tester/tree/v2.3.0#cli-interface) for accepted values.

## Traefik

Set `COMPOSE_VARIANT=traefik` and configure `TRAEFIK_HOST` to expose the application through the shared `websecure` entrypoint. See the common [Traefik usage guide](../_docs/traefik.md) and [external network guide](../_docs/traefik_network.md).

The router defaults to `default-access@file`, which is normally private. Webhook providers outside your private network cannot reach that route. Set this explicitly when public delivery is required:

```dotenv
TRAEFIK_ACCESS_POLICY=public-access@file
PUBLIC_URL_ROOT=https://webhooks.example.com
```

Public exposure allows anyone who knows or discovers a webhook URL to send requests to it. Review stored payloads for secrets and choose suitable `SESSION_TTL`, `MAX_REQUESTS`, and `MAX_REQUEST_BODY_SIZE` limits.
