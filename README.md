# Docker Compose config collection

## How to set up?

Basically you need to choose which service you want to run and then
create needed `.env` files from `.env.dist` template.

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
- [x] [Gatus](https://github.com/TwiN/gatus)
- [ ] [I2PD](https://github.com/PurpleI2P/i2pd)
- [x] [Joplin](https://hub.docker.com/r/joplin/server) (working, abandoned)
- [ ] Lidarr (didn't test, may not work)
- [x] magnetico-web-telegram
- [x] magneticod
- [x] magneticod-python
- [ ] mariadb-common (prototype state)
- [ ] mastodon (didn't work when tried to set up)
- [x] Murmur (Mumble server)
- [ ] NextCloud
- [x] Open Streaming Platform
- [x] OpenVPN
- [ ] [Owncast](https://owncast.online/)
- [x] Portainer
- [ ] Postgres Common (prototype state)
- [x] Proxy MTProto
- [x] Proxy Socks5
- [x] Radarr (prototype state, see sonarr)
- [x] Redis
- [x] Sonarr (prototype state, working itself, but transmission-on-host integration didn't work due to path mismatch)
- [x] Speedtest (LibreSpeed)
- [x] [Synapse](https://hub.docker.com/r/matrixdotorg/synapse) ([Matrix.org](https://matrix.org/) server)
- [x] [Syncthing](https://hub.docker.com/r/linuxserver/syncthing)
- [x] [Tor Privoxy](https://hub.docker.com/r/dperson/torproxy)
- [x] Watchtower
- [ ] [Wireguard](https://hub.docker.com/r/cmulk/wireguard-docker) (prototype state, not working yet)
- [ ] Wordpress (prototype state)
- [ ] YaCy (abandoned due to upstream code problems)
