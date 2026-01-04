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
requests to the Mox web listeners configured in `config/mox.conf`. Quickstart will
also place placeholder TLS certificate paths in `config/mox.conf` for the public
SMTP/IMAP listener; you must replace them with real cert paths from `acme.sh`.

##### 1.4.1 Choose and understand hostnames

Quickstart prints the DNS records you need. Those records typically include:

- A hostname for SMTP/IMAP (often `mail.example.com`) that becomes your MX host.
- `mta-sts.example.com` for the MTA-STS policy.
- `autoconfig.example.com` for mail client auto-configuration.

You can change hostnames in the quickstart output, but make sure you:
1) create DNS records for them, 2) issue certificates for them, and 3) proxy each
hostname to the right Mox listener via Nginx.

##### 1.4.2 Update TLS cert paths in `config/mox.conf`

Quickstart writes placeholder paths for the public listener TLS certificates. Replace
them with the real paths that `acme.sh` writes on your host.
Use the same certs/keys that Nginx serves for those hostnames.

Example (paths are placeholders, use your actual `acme.sh` locations):

```text
Listeners:
	public:
		TLS:
			KeyCerts:
				- CertFile: /etc/ssl/acme/mail.example.com/fullchain.cer
				  KeyFile: /etc/ssl/acme/mail.example.com/key.pem
				- CertFile: /etc/ssl/acme/mta-sts.example.com/fullchain.cer
				  KeyFile: /etc/ssl/acme/mta-sts.example.com/key.pem
				- CertFile: /etc/ssl/acme/autoconfig.example.com/fullchain.cer
				  KeyFile: /etc/ssl/acme/autoconfig.example.com/key.pem
```

If you use a wildcard certificate that covers all of these hostnames, you can point
all entries at that single cert/key.

##### 1.4.3 Configure Mox internal listeners for proxying

The following is aligned with the upstream quickstart for `-existing-webserver`:
it keeps all web endpoints on localhost, uses port 1080 for account/admin/webmail,
and port 81 for autoconfig/MTA-STS/webserver. `Forwarded: true` tells Mox to trust
`X-Forwarded-*` headers from Nginx.

```text
Listeners:
	internal:
		IPs:
			- 127.0.0.1
		Hostname: localhost
		AdminHTTP:
			Enabled: true
			Port: 1080
			Forwarded: true
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
		MTASTSHTTPS:
			Enabled: true
			Port: 81
			NonTLS: true
		WebserverHTTP:
			Enabled: true
			Port: 81
```

Note: Mox config uses tabs for indentation.

##### 1.4.4 Nginx reverse-proxy examples

Mail/web UI host (proxy to port 1080):

```nginx
server {
	listen 80;
	listen 443 ssl http2;
	server_name mail.example.com;

	# Optional HTTP->HTTPS redirect
	# if ($scheme = http) { return 301 https://$host$request_uri; }

	# SSL config from acme.sh (use your local include/snippet)
	#include ssl-domain.conf;

	location / {
		proxy_pass http://127.0.0.1:1080;
		proxy_set_header Host $host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
	}

	# Optional: lock down admin UI
	#location /admin/ {
	#	allow 192.168.0.0/16;
	#	deny all;
	#	proxy_pass http://127.0.0.1:1080;
	#	proxy_set_header Host $host;
	#	proxy_set_header X-Real-IP $remote_addr;
	#	proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	#	proxy_set_header X-Forwarded-Proto $scheme;
	#}
}
```

Autoconfig + MTA-STS hostnames (proxy to port 81, plain HTTP to Mox):

```nginx
server {
	listen 80;
	listen 443 ssl http2;
	server_name autoconfig.example.com mta-sts.example.com;

	# SSL config from acme.sh (use your local include/snippet)
	#include ssl-domain.conf;

	location / {
		proxy_pass http://127.0.0.1:81;
		proxy_set_header Host $host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
	}
}
```

If you only want to expose webmail or web API, proxy `/webmail/` and/or `/webapi/`
instead of `/`. If you want admin access private, keep `/admin/` restricted via
Nginx allow/deny or expose it only on an internal/VPN-only virtual host.

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
other sites you serve. See section 1.4 for the full reverse-proxy checklist.

## Notes

- The `web` directory is optional; it is used for static files served by Mox.
- If you want Mox to manage ACME and serve the admin UI directly, keep ports 80/443
  available for Mox.
- See the Mox install docs and docker-compose example for more details.
