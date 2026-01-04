# Mox

Mox runs with Docker `host` networking so it can see the host's public IPs and the real
client IPs for filtering and rate limiting.

### 1. First-time setup

#### 1.1 Prepare directories

Ensure the `config`, `data`, and `web` directories exist (or update `.env` to point
elsewhere). This README assumes you are in the `mox/` stack directory on the host.

#### 1.2 (Recommended) Create a dedicated system user

The upstream Docker quickstart uses a dedicated user so generated files are owned
by that user. This is recommended but optional when using Docker.

Create a user and set its home to the `mox/` directory:

```shell
sudo useradd -m -d "$(pwd)" mox
```

#### 1.3 Run quickstart

Run quickstart to generate config files and DNS instructions:

```shell
docker-compose run --rm mox mox quickstart you@yourdomain.example $(id -u mox)
```

If you run quickstart on a different machine than the final host, add
`-hostname mail.example.com`.

#### 1.4 Using an existing Nginx on 80/443

If you already run Nginx on ports 80/443, add `-existing-webserver` to quickstart
so Mox does not try to bind those ports:

```shell
docker-compose run --rm mox mox quickstart -existing-webserver you@yourdomain.example $(id -u mox)
```

When using `-existing-webserver`, you must terminate TLS in Nginx and reverse-proxy
requests to the Mox web listeners configured in `config/mox.conf`.

Example: enable Mox HTTP listeners on localhost and a single port (e.g. 8080) and
enable `Forwarded` so Mox trusts `X-Forwarded-*` headers from Nginx:

```yaml
Listeners:
	internal:
		IPs:
			- 127.0.0.1
		AdminHTTP:
			Enabled: true
			Port: 8080
			Forwarded: true
		AccountHTTP:
			Enabled: true
			Port: 8080
			Forwarded: true
		WebmailHTTP:
			Enabled: true
			Port: 8080
			Forwarded: true
		WebAPIHTTP:
			Enabled: true
			Port: 8080
			Forwarded: true
```

Then proxy `mail.example.com` to that local listener in Nginx (TLS handled by Nginx):

```nginx
server {
	listen 80;
	listen 443 ssl;
	server_name mail.example.com;

	location / {
		proxy_pass http://127.0.0.1:8080;
		proxy_set_header Host $host;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
	}
}
```

If you only want to expose the admin UI, proxy `/admin/` (and/or `/webmail/`,
`/webapi/`) instead of the root path, and leave `/` to your main site.

### 2. Running in production

#### 2.1 Review configuration and DNS

Review `config/mox.conf` and `config/domains.conf`, then apply the DNS records
printed by quickstart.

#### 2.2 Start the server

```shell
docker-compose up -d
```

#### 2.3 Reverse proxy with Nginx (if ports 80/443 are already in use)

If you use Nginx on 80/443, keep it there and proxy requests to the Mox web listener
configured in `config/mox.conf`. Ensure Nginx also handles ACME/TLS for Mox and any
other sites you serve.

## Notes

- The `web` directory is optional; it is used for static files served by Mox.
- If you want Mox to manage ACME and serve the admin UI directly, keep ports 80/443
  available for Mox.
- See the Mox install docs and docker-compose example for more details.
