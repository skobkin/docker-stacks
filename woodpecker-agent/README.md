# Woodpecker Docker Agent

Woodpecker CI Docker runner: https://woodpecker-ci.org/docs/administration/configuration/agent

## Persistent agent configuration

The agent keeps its registered identity (the agent ID issued by the server) in
`/etc/woodpecker/agent.conf` inside the container. This directory is mounted from
`./data` on the host (override with `HOST_DATA_DIR`). Without the mount the agent
cannot write the file and loses its identity on every container recreation,
re-registering as a new agent each time.

Do not place a static `agent.conf` template in `./data` — the agent creates and
updates the file on its own after the first successful registration.

## Connecting to the server

Set `WOODPECKER_SERVER` and `WOODPECKER_AGENT_SECRET` in `.env`. The secret is
either the shared system token (from the server's `WOODPECKER_AGENT_SECRET`) or a
per-agent token created in the server UI under *Settings → Agents → Add agent*.

TLS variables:

- `WOODPECKER_GRPC_SECURE=true` — connect to the server over TLS.
- `WOODPECKER_GRPC_SKIP_VERIFY=false` — verify the server certificate (keep this
  in production). Note that the upstream default is to *skip* verification, so
  this stack sets `false` explicitly. Set it to `true` only when the proxy
  terminating TLS uses a self-signed certificate.

## Verifying the installation

1. `docker compose up -d`, then check `docker compose logs --tail 50` — there
   should be no `could not persist agent config` errors.
2. `data/agent.conf` appears on the host after the first successful registration.
3. The agent shows up as connected in the server UI (*Settings → Agents*) or in
   the server's logs.
4. Run a workflow on the agent to confirm it picks up jobs
   (`platform: <os>/<arch>` label matching may apply).

## Updating existing installations

If you upgrade from a version of this stack without the `./data` mount, follow
the migration steps in the root [UPGRADE.md](../UPGRADE.md).
