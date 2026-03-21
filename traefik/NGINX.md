# Nginx to Traefik Migration

This guide describes a hybrid setup where host Nginx stays on the public `80` and `443` ports, while the Docker `traefik` stack handles everything that is not explicitly configured in Nginx yet.

The goal is simple:

- existing Nginx virtual hosts keep working unchanged from the outside
- new or migrated host names fall through to Traefik
- migration can happen one host at a time

## Requirements from Nginx

The HTTPS part of this setup needs more than a minimal Nginx install.

Required capabilities:

- HTTP proxy support for the port `80` fallback
- the `stream` module for TCP proxying on `443`
- `ssl_preread` support inside the `stream` module so Nginx can route by SNI without terminating TLS

On Debian and Ubuntu, do not assume the base Nginx package already includes that. A common requirement is installing the separate `libnginx-mod-stream` package and making sure its module load file is enabled under `modules-enabled/`.

Practical checks:

```shell
nginx -V 2>&1 | grep -o -- '--with-stream_ssl_preread_module'
ls /etc/nginx/modules-enabled/ | grep stream
```

If the first command prints nothing, or the stream module is not loaded, the HTTPS SNI-split example from this guide will not work until Nginx is rebuilt or the required module package is installed and enabled.

## 1. Move Traefik off host ports 80 and 443

Keep Traefik's internal entrypoints on `:80` and `:443`, but bind them to alternate localhost ports on the host.

In `traefik/.env`:

```dotenv
HTTP_BIND_ADDR=127.0.0.1
HTTP_BIND_PORT=8080
HTTPS_BIND_ADDR=127.0.0.1
HTTPS_BIND_PORT=8443
```

Then recreate the stack:

```shell
docker compose up -d
```

With this setup:

- Nginx keeps listening on public `80` and `443`
- Traefik listens only on `127.0.0.1:8080` and `127.0.0.1:8443`
- Traefik routers, entrypoints, and ACME settings stay unchanged inside the container

## 2. HTTP fallback from Nginx to Traefik

HTTP is the easy part. Keep explicit Nginx `server_name` blocks for legacy sites, then add a catch-all `default_server` that proxies everything else to Traefik.

Example:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name legacy.example.com;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
    }
}
```

Anything matched by an explicit Nginx virtual host stays on Nginx. Anything else reaches Traefik on `127.0.0.1:8080`.

If you use the `Upgrade` and `Connection` headers above, define the usual helper once in the `http` block:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
```

## 3. HTTPS fallback with SNI split

HTTPS cannot use the same `default_server` trick if Traefik should keep managing its own certificates for migrated hosts.

To make that work:

- public `:443` stays on Nginx
- Nginx `stream` inspects SNI with `ssl_preread`
- known legacy host names go to an internal Nginx TLS listener
- everything else goes to Traefik on `127.0.0.1:8443`

Example `stream` configuration:

```nginx
map $ssl_preread_server_name $https_backend {
    legacy.example.com nginx_https;
    old-app.example.com nginx_https;
    default traefik_https;
}

upstream nginx_https {
    server 127.0.0.1:4443;
}

upstream traefik_https {
    server 127.0.0.1:8443;
}

server {
    listen 443;
    listen [::]:443;
    proxy_pass $https_backend;
    ssl_preread on;
}
```

Then move the legacy HTTPS virtual hosts off the public socket and onto an internal TLS listener:

```nginx
server {
    listen 127.0.0.1:4443 ssl;
    server_name legacy.example.com;

    ssl_certificate /etc/letsencrypt/live/legacy.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/legacy.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

With that layout:

- `legacy.example.com` is still terminated and served by Nginx
- any host name not listed in the SNI map is passed through untouched to Traefik
- Traefik can still terminate TLS and use its own certificates for migrated hosts

This requires Nginx with the `stream` module and `ssl_preread` support. On Debian and Ubuntu, verify that before you start; some smaller package variants do not include the needed module set by default.

## 4. ACME and forwarded headers

This hybrid layout keeps Traefik's default HTTP-01 flow workable because unknown requests on public `:80` are forwarded to Traefik's `web` entrypoint on `127.0.0.1:8080`.

If you want Traefik to trust forwarded headers from host Nginx, set the trusted proxy IPs in `traefik/.env`:

```dotenv
TRAEFIK_ENTRYPOINTS_WEB_FORWARDEDHEADERS_TRUSTEDIPS=
TRAEFIK_ENTRYPOINTS_WEBSECURE_FORWARDEDHEADERS_TRUSTEDIPS=
```

Do not trust arbitrary sources there. Set those only to the real source IPs Traefik sees from your host Nginx path.

## 5. Migration workflow

Use this pattern to move one host at a time:

1. Keep the hostname in Nginx while it is still served by the old setup.
2. Prepare the Docker stack behind Traefik with `traefik.enable=true`, the shared `TRAEFIK_NETWORK`, and the correct router labels.
3. For HTTP, remove the explicit Nginx `server_name` block when you are ready.
4. For HTTPS, remove the hostname from the Nginx SNI map and, if needed, its internal TLS virtual host.
5. Reload Nginx. After that, unmatched traffic for that hostname falls through to Traefik.

## References

- Traefik entrypoints: https://doc.traefik.io/traefik/reference/install-configuration/entrypoints/
- Traefik ACME: https://doc.traefik.io/traefik/reference/install-configuration/tls/certificate-resolvers/acme/
- Nginx `proxy_pass`: https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass
- Nginx `stream` module: https://nginx.org/en/docs/stream/ngx_stream_core_module.html
- Nginx `ssl_preread`: https://nginx.org/en/docs/stream/ngx_stream_ssl_preread_module.html
