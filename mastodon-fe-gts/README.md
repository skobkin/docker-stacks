# Masto-FE GTS

A customized instance of Masto-FE (Mastodon Frontend) for GTS.

## Configuration

Before running the container, you need to set up your configuration:

1. Create `config/config.js` from `config.dist.js`:
   ```shell
   cp config/config.dist.js config/config.js
   ```

2. Edit `config/config.js` to set your instance address.

## Running

Use docker-compose to run the container:

```shell
docker-compose up -d
```

The frontend will be available at http://localhost:8398 (or your configured BIND_ADDR:BIND_PORT).
