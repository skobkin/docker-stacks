# Home Assistant

## Using with reverse proxy (like Nginx)

If you're using Home Assistant with reverse proxy, you need to enable it and add trusted proxy address. Otherwise you
will get 400 (Bad Request) each time you try to open HA's web interface.

To achieve that edit `configuration.yaml` after it was generated at first launch and add missing options.

```yaml
# config/configuration.yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - '127.0.0.1'
    - '::1'
```
