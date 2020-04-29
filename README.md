# Docker Compose config collection

## How to set up?

Basically you need to choose which service you want to run and then
create needed `.env` files from `.end.dist` template.

```shell
# Choose a service
cd folding-at-home
# Copy template
cp .env.dist .env
# edit the config to your preference
nano -w .env
# Create and run containers
docker-compose up -d
# Optional: check the logs
docker-compose logs -f
```

Some services may require additional configuration. Check for additional `README.md` files
or comments in the `docker-compose.yml` files or `.env.dist` templates.

## Is it working?

Not every stack is tested to fully work.

- [x] Duplicati
- [x] Folding@Home
- [ ] Lidarr (prototype state, see sonarr)
- [x] magnetico-web-telegram
- [x] magneticod
- [x] magneticod-python
- [ ] mariadb-common (prototype state)
- [ ] mastodon (didn't work when tried to set up)
- [x] Murmur (Mumble server)
- [x] Open Streaming Platform
- [x] OpenVPN
- [ ] Portainer (prototype state)
- [ ] Postgres Common (prototype state)
- [x] Proxy MTProto
- [x] Proxy Socks5
- [ ] Radarr (prototype state, see sonarr)
- [ ] Sonarr (prototype state, working itself, but transmission-on-host integration didn't work due to path mismatch)
- [ ] Wordpress (prototype state)
- [ ] YaCy (abandoned due to upstream code problems)
