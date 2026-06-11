# Mox

Mox runs with Docker host networking so it can see the host's public addresses
and real client IPs for filtering and rate limiting. Optional Traefik support
only proxies Mox's HTTP services; SMTP, submission, and IMAP continue to connect
directly to Mox.

## Initial setup

Create the local environment file and review its hostnames:

```shell
cp .env.dist .env
```

Ensure the `config`, `data`, and `web` directories exist, or override their
locations in `.env`.

The upstream Docker quickstart recommends a dedicated user so generated files
are owned by a stable UID:

```shell
sudo useradd -m -d "$(pwd)" mox
```

When Traefik already owns ports 80 and 443, generate the configuration with
`-existing-webserver`:

```shell
docker compose run --rm mox mox quickstart \
  -existing-webserver \
  you@example.com \
  "$(id -u mox)"
```

If quickstart runs on a different machine than the production mail host, add
`-hostname mail.example.com`.

Quickstart writes `config/mox.conf`, `config/domains.conf`, passwords, and the
required DNS records. Review all generated output before starting Mox.

## Traefik

Set `COMPOSE_VARIANT=traefik` and configure these hostnames in `.env`:

```dotenv
TRAEFIK_MAIL_HOST=mail.example.com
TRAEFIK_AUTOCONFIG_HOST=autoconfig.example.com
TRAEFIK_MTASTS_HOST=mta-sts.example.com
```

All three hostname variables are required when the Traefik variant is selected.
Keep them distinct in a normal deployment:

- `TRAEFIK_MAIL_HOST` is the mail server and client-settings hostname.
- `TRAEFIK_AUTOCONFIG_HOST` should be `autoconfig.<mail-domain>` so clients can
  discover it through the standard hostname.
- `TRAEFIK_MTASTS_HOST` must be `mta-sts.<mail-domain>` because MTA-STS
  discovery and Mox require that naming convention.

The mail and autoconfig routes can technically share a hostname when DNS and
client discovery are configured accordingly, but sharing all three does not
provide standards-compliant MTA-STS discovery.

The Traefik variant keeps `network_mode: host`. Traefik's Docker provider
detects host-networked containers and connects through `host.docker.internal`,
which the repository Traefik stack maps to the Docker host gateway.

The routers use this mapping:

| External hostname and path | Mox listener |
|----------------------------|--------------|
| `mta-sts.example.com/.well-known/mta-sts.txt` | Plain HTTP port `81` |
| `autoconfig.example.com/mail/config-v1.1.xml` | Plain HTTP port `81` |
| `mail.example.com/autodiscover/autodiscover.xml` | Plain HTTP port `81` |
| `mail.example.com/profile.mobileconfig` and `.qrcode.png` | Plain HTTP port `81` |
| `mail.example.com/`, `/webmail/`, and `/webapi/` | Plain HTTP port `1080` |

The MTA-STS and autoconfiguration routers default to
`public-access@file` because external mail systems and clients must reach them.
The account, webmail, and WebAPI router defaults to
`default-access@file`, which is normally private. Override
`TRAEFIK_PUBLIC_ACCESS_POLICY` or `TRAEFIK_WEB_ACCESS_POLICY` only when the
shared policies do not match the deployment.

Before using the public routes, install the shared public policy if it is not
already present:

```shell
cp ../traefik/config/dynamic/public-access.yml.dist \
  ../traefik/config/dynamic/public-access.yml
```

Traefik intentionally does not route `/admin/`. Access the loopback-only admin
interface through SSH:

```shell
ssh -L 1080:127.0.0.1:1080 user@mail.example.com
```

Then open `http://localhost:1080/admin/`.

See the common [Traefik guide](../_docs/traefik.md) for entrypoint and access
policy setup. Mox does not join the external Traefik network, so creating that
network is only a requirement of the shared Traefik stack itself.

### Configure a listener reachable from Traefik

The default `-existing-webserver` configuration may bind its internal listener
only to loopback. A bridge-networked Traefik container cannot connect to the
host's `127.0.0.1`.

Find the IPv4 address that Traefik uses for `host.docker.internal`:

```shell
docker exec traefik getent ahostsv4 host.docker.internal
```

Use the first address from that output, typically the Docker bridge gateway,
for a dedicated listener in `config/mox.conf`. Do not use `0.0.0.0`, because
that would expose ports 81 and 1080 on every host interface.

Mox configuration uses tabs for indentation:

```text
Listeners:
	proxy:
		IPs:
			- 172.17.0.1
		Hostname: mail.example.com
		AccountHTTP:
			Enabled: true
			Port: 1080
			Forwarded: true
		WebmailHTTP:
			Enabled: true
			Port: 1080
			Forwarded: true
		WebAPIHTTP:
			Enabled: true
			Port: 1080
			Forwarded: true
		AutoconfigHTTPS:
			Enabled: true
			Port: 81
			NonTLS: true
			Forwarded: true
		MTASTSHTTPS:
			Enabled: true
			Port: 81
			NonTLS: true
			Forwarded: true
		WebserverHTTP:
			Enabled: true
			Port: 81
```

Replace `172.17.0.1` and the hostname with values from the deployment. Do not
enable `AdminHTTP` on this listener.

Keep administration on a separate loopback listener. A configuration generated
by quickstart already has an `internal` listener. The minimal admin portion is:

```text
	internal:
		IPs:
			- 127.0.0.1
			- ::1
		Hostname: localhost
		AdminHTTP:
			Enabled: true
			Port: 1080
```

Multiple listeners can share port 1080 because they bind different addresses.
Other intended loopback-only services, such as metrics, can remain on the
`internal` listener.

## Updating an existing configuration

Do not rerun quickstart over an existing installation. Back up
`config/mox.conf` and edit its `Listeners` section.

For a configuration originally generated without `-existing-webserver`:

1. Keep SMTP, submissions, IMAPS, and their ports unchanged.
2. Provision PEM certificates for the mail protocol hostnames. In the public
   listener's `TLS` section, remove `ACME` and configure `KeyCerts` with those
   certificate and key paths. Leaving `TLS.ACME` enabled makes Mox continue
   listening on its ACME port, normally 443.
3. Disable or remove `AccountHTTPS`, `AdminHTTPS`, `WebmailHTTPS`,
   `WebAPIHTTPS`, `AutoconfigHTTPS`, `MTASTSHTTPS`, `WebserverHTTP`, and
   `WebserverHTTPS` from the public listener so Mox releases ports 80 and 443.
4. Add the dedicated `proxy` listener shown above.
5. Keep or add the loopback-only `internal` admin listener.

For a configuration already generated with `-existing-webserver`:

1. Keep the public SMTP, submissions, IMAPS, and TLS sections unchanged.
2. Remove account, webmail, WebAPI, autoconfig, MTA-STS, and webserver services
   from the existing `internal` listener.
3. Leave `AdminHTTP` on the loopback-only `internal` listener.
4. Add the dedicated `proxy` listener shown above, using the address resolved
   by Traefik.

Set `Forwarded: true` on every account, webmail, WebAPI, autoconfig, or MTA-STS
service reached through Traefik. This lets Mox use `X-Forwarded-*` headers for
client addresses, rate limits, logging, and secure cookies.

Validate the edited configuration before restarting:

```shell
docker compose run --rm mox mox config test
```

## Mail protocol certificates

Traefik terminates HTTPS only. Mox still terminates TLS for SMTP STARTTLS,
submissions, and IMAPS, so the public listener must retain readable PEM
certificate and key files covering the mail server and client-settings
hostnames used by those protocols.

Traefik's `acme.json` cannot be referenced directly by Mox. Provision separate
PEM files with an ACME client or another certificate workflow and place them
under the mounted Mox configuration directory, or mount another host directory
containing them. Update `Listeners.public.TLS.KeyCerts` in `config/mox.conf`.
Remove obsolete MTA-STS or autoconfig certificate entries only when those names
are used exclusively through Traefik; do not remove certificates required by
SMTP, submission, or IMAP hostnames.

## Start and review

Review `config/mox.conf`, `config/domains.conf`, and all DNS records printed by
quickstart, then start the service:

```shell
docker compose up -d
```

The optional `web` directory contains static files served by configured Mox
web handlers.

See the upstream [Docker installation guide](https://www.xmox.nl/install/#hdr-docker),
[configuration reference](https://www.xmox.nl/config/), and
[reference Compose file](https://github.com/mjl-/mox/blob/main/docker-compose.yml)
for additional details.
