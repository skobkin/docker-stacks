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

- [x] [Duplicati](https://hub.docker.com/r/linuxserver/duplicati)
- [x] [Folding@Home](https://hub.docker.com/r/johnktims/folding-at-home)
- [x] [Gatus](https://github.com/TwiN/gatus)
- [x] [Gitea](https://gitea.io/)
- [x] [I2PD](https://github.com/PurpleI2P/i2pd)
- [x] [~~JDownloader~~](https://jdownloader.org) (tested, but abandoned)
- [x] [Joplin](https://hub.docker.com/r/joplin/server) (working, abandoned)
- [ ] [Lidarr](https://hub.docker.com/r/linuxserver/lidarr) (didn't test, may not work)
- [x] [magnetico-web-telegram](https://hub.docker.com/r/skobkin/magnetico-web-telegram-bot)
- [x] [magneticod](https://hub.docker.com/r/boramalper/magneticod)
- [x] [~~magneticod-python~~](https://hub.docker.com/r/skobkin/magneticod-python) (legacy)
- [ ] ~~mariadb-common~~ (abandoned for now)
- [x] [Murmur](https://gitlab.com/skobkin/docker-murmur/container_registry/2667847) (Mumble server)
- [ ] [NextCloud](https://hub.docker.com/r/linuxserver/nextcloud)
- [x] [Open Streaming Platform](https://hub.docker.com/r/deamos/openstreamingplatform)
- [x] [OpenVPN](https://hub.docker.com/r/kylemanna/openvpn)
- [ ] [Owncast](https://owncast.online/)
- [x] [Portainer](https://hub.docker.com/r/portainer/portainer)
- [ ] ~~Postgres Common~~ (abandoned for now)
- [x] [Proxy MTProto](https://hub.docker.com/r/mtproxy/mtproxy)
- [x] [Proxy Socks5](https://hub.docker.com/r/serjs/go-socks5-proxy)
- [x] [Radarr](https://hub.docker.com/r/linuxserver/radarr)
- [x] [Redis](https://hub.docker.com/_/redis)
- [x] [Sonarr](https://hub.docker.com/r/linuxserver/sonarr)
- [x] [Speedtest](https://hub.docker.com/r/adolfintel/speedtest) (LibreSpeed)
- [x] [Synapse](https://hub.docker.com/r/matrixdotorg/synapse) ([Matrix.org](https://matrix.org/) server)
- [x] [Syncthing](https://hub.docker.com/r/linuxserver/syncthing)
- [x] [Tor Privoxy](https://hub.docker.com/r/dperson/torproxy)
- [x] [Watchtower](https://hub.docker.com/r/containrrr/watchtower)
- [ ] [Wireguard](https://hub.docker.com/r/cmulk/wireguard-docker) (prototype state, not working yet)
- [ ] ~~Wordpress~~ (abandoned)
