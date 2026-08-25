# Samba

Self-hosted SMB/CIFS file sharing using the
[`ghcr.io/crazy-max/samba`](https://github.com/crazy-max/docker-samba) image.

The image is run with **`network_mode: host`** so Samba can bind TCP/445
directly on the host network — required for SMB performance, multichannel,
and interface visibility. No ports are published through the Docker bridge.

## Quick start

```shell
cd samba
cp .env.dist .env
nano -w .env              # set HOST_STORAGE_DIR to a real host path
cp config/config.yml.dist config/config.yml
nano -w config/config.yml # fill in users, shares, and trusted-network policy
docker compose up -d
docker compose logs -f
```

The default upstream `SAMBA_HOSTS_ALLOW` covers the usual private IPv4
ranges (`127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`).
Adjust it in your real `config/config.yml` (`global:`) or via environment
if your deployment needs a different policy.

## Files

- `.env` (local, gitignored) — image tag, host paths, generic
  `SAMBA_*` knobs, logging settings.
- `config/config.yml` (local, gitignored) — your real Samba configuration:
  `auth:`, `global:`, `share:`. See `config/config.yml.dist` for the
  minimal structural template, and the upstream [Configuration reference](https://github.com/crazy-max/docker-samba#configuration)
  for the full schema (`auth`/`global`/`share` keys, `password_file`
  support, `veto`/`hidefiles`/`recycle`/`options` per-share, and the
  available `SAMBA_*` / `AVAHI_*` / `WSDD2_*` environment variables).
- `secrets/` (local, gitignored) — password files referenced from
  `config/config.yml` as `password_file: /run/secrets/<name>`.

## Password files

Plaintext passwords in `config/config.yml` are easy to leak by accident.
The image supports `password_file:` per user — drop a file under
`secrets/` on the host, restrict its permissions, and reference it:

```shell
chmod 0400 secrets/alice_password
```

```yaml
# config/config.yml
auth:
  - user: alice
    group: alice
    uid: 1000
    gid: 1000
    password_file: /run/secrets/alice_password
```

## Service discovery

Avahi (mDNS, Linux/macOS) and WSDD2 (WS-Discovery, Windows) are both
**off by default** upstream and are not enabled by this stack. Operators
who want LAN-side automatic discovery should enable them deliberately
via the image's environment variables (see upstream docs).

## Image-provided healthcheck

The upstream image ships a Docker `HEALTHCHECK` (s6 service probe
including `smbd`). It is inherited unchanged. No custom Compose
healthcheck is configured here — `network_mode: host` makes per-service
Compose healthchecks awkward and would be redundant with the image's
own probe.

## Docs

- Image source and release notes:
  [github.com/crazy-max/docker-samba](https://github.com/crazy-max/docker-samba)
- Configuration reference:
  [github.com/crazy-max/docker-samba#configuration](https://github.com/crazy-max/docker-samba#configuration)
- smb.conf options:
  [samba.org manpage](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html)
- Port usage:
  [Samba NT4 PDC port usage](https://wiki.samba.org/index.php/Samba_NT4_PDC_Port_Usage)