# Matrix Calls

This stack runs the MatrixRTC backend pieces needed for native Matrix calls with Continuwuity:

- LiveKit SFU
- `lk-jwt-service` for Matrix OpenID to LiveKit JWT exchange

It does not include Element Call web UI, recording, LiveKit Egress, Redis, recording storage, or TURN.

## Quick start

```shell
cp .env.dist .env
docker run --rm livekit/livekit-server:v1.12.0 generate-keys
nano -w .env
docker compose up -d
```

Put the generated API key and secret into `LIVEKIT_KEY` and `LIVEKIT_SECRET`. Set `LIVEKIT_FULL_ACCESS_HOMESERVERS` to your Matrix server name, for example `example.com`.

## Networking

LiveKit should use a dedicated calls hostname such as `calls.example.com`.

The default stack publishes:

- `127.0.0.1:7880/tcp` for LiveKit HTTP/API and WebSocket signaling
- `127.0.0.1:8411/tcp` for `lk-jwt-service`
- `0.0.0.0:7881/tcp` for LiveKit ICE over TCP
- `0.0.0.0:50100-50200/udp` for LiveKit ICE over UDP

Open `7881/tcp` and `50100-50200/udp` on the host firewall. Keep `7880/tcp` and `8411/tcp` behind TLS through a reverse proxy.

## Traefik

Set `COMPOSE_VARIANT=traefik` and `TRAEFIK_HOST=calls.example.com`.

The Traefik variant uses one hostname:

- `/sfu/get`, `/healthz`, and `/get_token` route to `lk-jwt-service`
- all other paths route to LiveKit

Matrix clients must be able to reach this hostname. If the shared Traefik default policy is private, set:

```dotenv
TRAEFIK_ACCESS_POLICY=public-access@file
```

or another equivalent public middleware chain.

See the [common Traefik guide](../_docs/traefik.md) and the [external Traefik network guide](../_docs/traefik_network.md).

## Continuwuity

Calls stay disabled until Continuwuity advertises the LiveKit focus. If you use the env-first Continuwuity stack, enable this in `continuwuity/.env`:

```dotenv
CONTINUWUITY_MATRIX_RTC__FOCI=[{type="livekit",livekit_service_url="https://calls.example.com"}]
```

The equivalent TOML form is:

```toml
[global.matrix_rtc]
foci = [
  { type = "livekit", livekit_service_url = "https://calls.example.com" },
]
```

Restart Continuwuity after changing the config.

## Testing

Fetch the MatrixRTC transport discovery from Continuwuity with a Matrix session token:

```shell
curl -H "Authorization: Bearer <session-access-token>" \
  https://matrix.example.com/_matrix/client/unstable/org.matrix.msc4143/rtc/transports
```

Request an OpenID token:

```shell
curl -X POST -H "Authorization: Bearer <session-access-token>" \
  https://matrix.example.com/_matrix/client/v3/user/@user:example.com/openid/request_token
```

Create `payload.json`:

```json
{
  "room_id": "abc",
  "slot_id": "xyz",
  "openid_token": {
    "matrix_server_name": "example.com",
    "access_token": "<openid_access_token>",
    "token_type": "Bearer"
  },
  "member": {
    "id": "xyz",
    "claimed_device_id": "DEVICEID",
    "claimed_user_id": "@user:example.com"
  }
}
```

Exchange it for a LiveKit JWT:

```shell
curl -X POST -d @payload.json https://calls.example.com/get_token
```

The response should include a `url` and `jwt`. Test them with the [LiveKit Connection Tester](https://livekit.io/connection-test).

## TURN

TURN is not configured in this stack. For unreliable networks, add LiveKit built-in TURN or an external coturn deployment later. Keep TURN relay port ranges separate from `50100-50200/udp`.

## Docker Loopback Caveat

Some hosts do not let Docker containers connect back through the host public IP. If `lk-jwt-service` logs connection refused or timeout errors while calling `https://calls.example.com` or the Matrix homeserver, test from a sidecar container:

```shell
docker run --rm --net container:matrix-calls-lk-jwt-service docker.io/curlimages/curl https://calls.example.com
```

If this fails, use host-reachable DNS, a local reverse-proxy address, or another upstream-recommended workaround before exposing the service publicly.

## References

- https://raw.githubusercontent.com/continuwuity/continuwuity/refs/heads/main/docs/calls/livekit.mdx
- https://github.com/element-hq/lk-jwt-service
- https://github.com/livekit/livekit
