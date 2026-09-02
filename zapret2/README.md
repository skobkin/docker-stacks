# zapret2

Anti-DPI egress proxy: the [zapret2](https://github.com/bol-van/zapret2)
`nfqws2` daemon (with Lua-based desync strategies) wrapped by the
[vernette/ss-zapret2](https://github.com/vernette/ss-zapret2) image together
with a Shadowsocks/SOCKS5 entry point.

Scope notes:

- Only traffic routed through this container gets the DPI treatment. This is
  not a host-wide bypass.
- The NFQUEUE machinery is Linux-only.

## Prerequisites

This service requires the `proxy` Docker network. Please follow the
[network configuration guide](../_docs/proxy_network.md) before starting the
service.

## Quick start

`config/config` must exist before the first start: the compose file bind-mounts
it as a single file, and starting without it makes Docker create a directory in
its place instead.

```shell
cp .env.dist .env
openssl rand -base64 24   # paste the value into SS_PASSWORD in .env
nano -w .env
cp config/config.dist config/config
docker compose up -d
```

## Configuration flow

- `config/config` is the live zapret2 config. The default strategy set in
  `NFQWS2_OPT` is a generic starting point — expect to tune it for your ISP.
- `data/lua`, `data/fake` and `data/custom.d` are seeded from the image on
  first start and are then yours to edit. Config changes apply on
  `docker compose restart`.
- Builtin custom script examples are available inside the container at
  `/opt/zapret2/init.d/custom.d.examples.linux` (not mounted).

## Usage

Clients on the `proxy` network use the in-network SOCKS5 endpoint:

```shell
ALL_PROXY=socks5://zapret2:1080
```

(the same pattern other stacks use for `mihomo`), while host-side clients go
through the published port:

```shell
curl --socks5-hostname 127.0.0.1:1060 https://ifconfig.me
```

The Shadowsocks listener (`zapret2:8388`) is container-internal only: it is the
encrypted hop between `ss-local` and `ss-server` and is intentionally not
published to the host.

## Strategy tuning

To find strategies that work against your censor:

1. Stop the desync daemon: `docker compose exec zapret2 /opt/zapret2/init.d/sysv/zapret2 stop`
2. Run the checker interactively: `docker compose exec zapret2 /opt/zapret2/blockcheck2.sh`
3. Translate the findings into `NFQWS2_OPT` in `config/config`
4. `docker compose restart`

## Security

- The SOCKS5 entry point has **no authentication at all**. Keep
  `SOCKS_BIND_ADDRESS` at `127.0.0.1` and never expose it beyond networks you
  fully trust.
- The Shadowsocks hop is password-protected, so a strong `SS_PASSWORD` is
  still required even though the listener is not published.
- The image is an unsigned third-party build (sources fetched at build time
  without pinned checksums) bundling the genuine bol-van/zapret2 upstream. The
  tag is pinned in `.env.dist`; review upstream releases before bumping instead
  of letting watchtower track it blindly.

For general setup instructions, please refer to the [root README](../README.md).
