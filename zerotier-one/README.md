# ZeroTier One

Runs the official ZeroTier One container in host network mode so the ZeroTier interface is created in the host network namespace.

## Setup

1. Copy `.env.dist` to `.env`.
2. Set `NETWORK_ID` to the ZeroTier network ID this node should join.
3. Start the stack with `docker compose up -d`.
4. Authorize the new member in ZeroTier Central.

The container needs `/dev/net/tun`, `NET_ADMIN`, and `SYS_ADMIN` for TAP/TUN operation. The node identity and joined network state are stored under `${HOST_DATA_DIR:-./data}`.

`ZEROTIER_API_SECRET`, `ZEROTIER_IDENTITY_PUBLIC`, and `ZEROTIER_IDENTITY_SECRET` can be set in `.env` when you need a fixed local API token or pre-generated node identity.
