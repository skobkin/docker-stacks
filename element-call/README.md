# Element Call

## Prerequisites

This stack requires the external Docker network `matrix`. Create it first:

```shell
docker network create matrix
```

See the detailed guide in `../_docs/matrix_network.md`. For general setup, follow the root `README.md`.

## Synapse changes

1. Enable the required MSCs and related limits in `homeserver.yaml`:

```yaml
experimental_features:
  # MSC3266: Room summary API. Used for knocking over federation
  msc3266_enabled: true
  # MSC4222 needed for syncv2 state_after. This allow clients to
  # correctly track the state of the room.
  msc4222_enabled: true

# The maximum allowed duration by which sent events can be delayed, as
# per MSC4140.
max_event_delay_duration: 24h

rc_message:
  # This needs to match at least e2ee key sharing frequency plus a bit of headroom
  # Note key sharing events are bursty
  per_second: 0.5
  burst_count: 30

rc_delayed_event_mgmt:
  # This needs to match at least the heart-beat frequency plus a bit of headroom
  # Currently the heart-beat is every 5 seconds which translates into a rate of 0.2s
  per_second: 1
  burst_count: 20
```

2. Ensure Synapse has either a `federation` or `openid` listener configured.

3. Update `/.well-known/matrix/client` on your Matrix site to advertise the MatrixRTC backend:

```json
{
  "org.matrix.msc4143.rtc_foci": [
    {
      "type": "livekit",
      "livekit_service_url": "https://ec.domain.tld/livekit/jwt"
    }
  ]
}
```

Make sure the well-known response is served as `application/json` and includes permissive CORS headers.

4. Route the MatrixRTC endpoints to this stack via Nginx (TLS terminates at Nginx; Element Call stays HTTP-only). See `./nginx/element-call.conf` for a complete example using `ec.domain.tld`.
