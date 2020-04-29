# Configuration

## Serve HTTP from the container

By default NextCloud internal Nginx config has redirects from internal 80 port
to 443 (HTTPS).
So if you want to reverse-proxy Nextcloud, you'll need to have a plain HTTP
connection to the Nextcloud.

Example of `/config/nginx/site-confs/default` changes:

```
#server {
#    listen 80;
#    listen [::]:80;
#    server_name _;
#    return 301 https://$host$request_uri;
#}
server {
    #listen 443 ssl http2;
    listen 80;
    listen [::]:80;
    #listen [::]:443 ssl http2;                                                                
    server_name _;
    #ssl_certificate /config/keys/cert.crt;
    #ssl_certificate_key /config/keys/cert.key;
```

You'll have access to the Nextcloud Nginx config after first run of Nextcloud
container. Don't forget to configure `/config` bind mount.