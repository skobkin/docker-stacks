[![Build Status](https://ci.skobk.in/api/badges/skobkin/docker-stacks/status.svg)](https://ci.skobk.in/skobkin/docker-stacks)

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

## Using a database server on the host from the container

You need to change your database configuration to be able to do that. Check 
[this](_docs/access_database_on_host_from_docker.md) documentation.

## Is it working?

Not every stack is tested to fully work.

| App Name                | Status       | Image                                        | Description                                                    | Links                                                                                                                                                                                                                       |
|-------------------------|--------------|----------------------------------------------|----------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ARK Server              | ✅            | `thmhoag/arkserver`                          | ARK: Survival Evolved game server with ArkManager.             | [Website](http://playark.com), [Steam](https://store.steampowered.com/app/346110/ARK_Survival_Evolved/), [Image Github](https://github.com/thmhoag/arkserver), [ArkManager](https://github.com/arkmanager/ark-server-tools) |
| Drone                   | ✅            | `drone/drone`                                | Continuous integration platform.                               | [Website](https://www.drone.io), [Github](https://github.com/harness/drone), [Image](https://hub.docker.com/r/drone/drone)                                                                                                  |
| Drone Docker Runner     | ✅            | `drone/drone-runner-docker`                  | CI runner daemon for Docker.                                   | [Website](https://www.drone.io), [Github](https://github.com/drone-runners/drone-runner-docker), [Image](https://hub.docker.com/r/drone/drone-runner-docker)                                                                |
| Duplicati               | ✅            | `linuxserver/duplicati`                      | Backup solution with many storage backends.                    | [Website](https://www.duplicati.com), [Github](https://github.com/duplicati/duplicati)                                                                                                                                      |
| Element-web             | ✅            | `vectorim/element-web`                       | Web Matrix client.                                             | [Website](https://element.io), [Github](https://github.com/vector-im/element-web/)                                                                                                                                          |
| emby                    | ✅            | `emby/embyserver`                            | Media server with online transcoding support.                  | [Website](https://emby.media)                                                                                                                                                                                               |
| Folding@Home            | ✅            | `johnktims/folding-at-home`                  | Protein folding distributed computing platform.                | [Website](https://foldingathome.org), [My guide](https://skobk.in/2020/06/folding-at-home-quick-start/)                                                                                                                     |
| Gatus                   | ✅            | `twinproduction/gatus`                       | Advanced service(s) status page.                               | [Website](https://gatus.io), [Github](https://github.com/TwiN/gatus)                                                                                                                                                        |
| Gitea                   | ✅            | `gitea/gitea`                                | Lightweight Git hosting platfom.                               | [Website](https://gitea.io/), [Github](https://github.com/go-gitea/gitea)                                                                                                                                                   |
| Homer                   | ✅            | `b4bz/homer`                                 | Server homepage generator.                                     | [Github](https://github.com/bastienwirtz/homer), [Demo](https://homer-demo.netlify.app), [Configuration](https://github.com/bastienwirtz/homer/blob/main/docs/configuration.md)                                             |
| I2PD                    | ✅            | `purplei2p/i2pd`                             | The Invisible Internet router.                                 | [Website](https://i2pd.website), [Github](https://github.com/PurpleI2P/i2pd/), [I2P project](https://geti2p.net/)                                                                                                           |
| InBucket                | ✅            | `inbucket/inbucket`                          | Testing SMTP/POP3 mail server with web interface.              | [Website](https://www.inbucket.org), [Github](https://github.com/inbucket/inbucket)                                                                                                                                         |
| ~~JDownloader~~         | ✅ Abandoned  | `jaymoulin/jdownloader`                      | Download manager with paid/ad file hosting support.            | [Website](https://jdownloader.org)                                                                                                                                                                                          |
| ~~Joplin~~              | ✅ Abandoned  | `joplin/server`                              | Markdown GTD / notes manager synchronization server.           | [Website](https://joplinapp.org), [Github](https://github.com/laurent22/joplin)                                                                                                                                             |
| Killing Floor 2 server  | ✅ Abandoned  | `jeeaaasustest/killingfloor2-srv`            | Killing Floor 2 game server.                                   |                                                                                                                                                                                                                             |
| Lidarr                  | Not tested   | `linuxserver/lidarr`                         | Music downloader and manager.                                  | [Website](https://lidarr.audio), [Github](https://github.com/Lidarr/Lidarr), [Wiki](https://wiki.servarr.com/lidarr)                                                                                                        |
| magnetico-web           | ✅            | `skobkin/magnetico-web`                      | DHT indexer private web search front-end.                      | [Git](https://git.skobk.in/skobkin/magnetico-web), [Git mirror](https://gitlab.com/skobkin/magnetico-web)                                                                                                                   |
| magnetico-web-telegram  | ✅            | `skobkin/magnetico-web-telegram-bot`         | Magnetico Web Telegram bot.                                    | [Bitbucket](https://bitbucket.org/skobkin/magnetico-web-telegram-bot/)                                                                                                                                                      |
| magneticod              | ✅            | `boramalper/magneticod`                      | DHT indexing daemon.                                           | [Website](https://www.boramalper.org/labs/magnetico/), [Github](https://github.com/boramalper/magnetico)                                                                                                                    |
| ~~magneticod-python~~   | ✅ Abandoned  | `skobkin/magneticod-python`                  | DHT indexing daemon (legacy version)                           | [Website](https://www.boramalper.org/labs/magnetico/), [Github](https://github.com/boramalper/magnetico)                                                                                                                    |
| ~~mariadb-common~~      | ❌ Unfinished | `mariadb`                                    | MariaDB database for common use.                               | [Website](https://mariadb.org)                                                                                                                                                                                              |
| Matrix Telegram Bridge  | ✅            | `dock.mau.dev/mautrix/telegram`              | Telegram bridge for Matrix server                              | [Gitlab](https://mau.dev/mautrix/telegram/)                                                                                                                                                                                 |
| Metube                  | ✅            | `alexta69/metube`                            | Web GUI for yt-dlp.                                            | [Github](https://github.com/alexta69/metube)                                                                                                                                                                                |
| Murmur (Mumble server)  | ✅            | `registry.gitlab.com/skobkin/docker-murmur`  | Mumble VoIP server (custom build)                              | [Website](https://www.mumble.info), [Github](https://github.com/mumble-voip/mumble)                                                                                                                                         |
| NextCloud               | ❌ Unfinished | `nextcloud`                                  | File management, synchronization, management and GTD platform. | [Website](https://nextcloud.com), [Github](https://github.com/nextcloud/server)                                                                                                                                             |
| Open Streaming Platform | ✅            | `deamos/openstreamingplatform`               | Live streaming platform.                                       | [Website](https://openstreamingplatform.com), [Gitlab](https://gitlab.com/osp-group/flask-nginx-rtmp-manager)                                                                                                               |
| OpenVPN                 | ✅            | `kylemanna/openvpn`                          | OpenVPN server with some management toolkit.                   | [Website](https://openvpn.net), [Image Github](https://www.github.com/kylemanna/docker-openvpn)                                                                                                                             |
| Owncast                 | ✅            | `gabekangas/owncast`                         | Live streaming platform with federation support.               | [Website](https://owncast.online), [Github](https://github.com/owncast/owncast)                                                                                                                                             |
| Portainer               | ✅            | `portainer/portainer`                        | Docker Container management web UI.                            | [Website](https://www.portainer.io), [Github](https://github.com/portainer/portainer)                                                                                                                                       |
| ~~Postgres Common~~     | ❌ Unfinished | `postgres`                                   | PostgreSQL database for common use.                            | [Website](https://www.postgresql.org)                                                                                                                                                                                       |
| Proxy MTProto           | ✅            | `mtproxy/mtproxy`                            | MTProto Telegram proxy.                                        | [Website](https://telegram.org), [Github](https://github.com/TelegramMessenger/MTProxy)                                                                                                                                     |
| Proxy Socks5            | ✅            | `serjs/go-socks5-proxy`                      | Simple SOCKS5 proxy.                                           | [Github](https://github.com/serjs/socks5-server)                                                                                                                                                                            |
| qBittorrent             | ✅            | `linuxserver/qbittorrent`                    | qBittorrent (noX)                                              | [Website](https://www.qbittorrent.org), [LinuxServer Fleet](https://fleet.linuxserver.io/image?name=linuxserver/qbittorrent)                                                                                                |
| Radarr                  | ✅            | `linuxserver/radarr`                         | Movie downloader and manager.                                  | [Website](https://radarr.video), [Github](https://github.com/Radarr/Radarr), [Wiki](https://wiki.servarr.com/radarr)                                                                                                        |
| Redis                   | ✅            | `redis`                                      | Redis storage server.                                          | [Website](https://redis.io), [Github](https://github.com/redis/redis-io)                                                                                                                                                    |
| Shadowsocks Client      | ✅            | `ghcr.io/shadowsocks/sslocal-rust:latest`    | Shadowsocks client (and SOCKS/HTTP/tunnel server).             | [Website](https://shadowsocks.org), [Github](https://github.com/shadowsocks/shadowsocks-rust), [Configuration](https://github.com/shadowsocks/shadowsocks-rust#getting-started)                                             |
| Shinobi                 | ✅            | `shinobisystems/shinobi`                     | Shinobi surveillance system                                    | [Website](https://shinobi.video), [Github](https://github.com/ShinobiCCTV/Shinobi)                                                                                                                                          |
| Sonarr                  | ✅            | `linuxserver/sonarr`                         | TV Shows, series and anime downloader and manager.             | [Website](https://sonarr.tv), [Github](https://github.com/Sonarr/Sonarr), [Wiki](https://wiki.servarr.com/sonarr)                                                                                                           |
| Speedtest               | ✅            | `adolfintel/speedtest`                       | Libre speed test implementation.                               | [Website](https://librespeed.org), [Github](https://github.com/librespeed/speedtest)                                                                                                                                        |
| Synapse                 | ✅            | `matrixdotorg/synapse`                       | Matrix reference server written in Python.                     | [Website](https://matrix.org/docs/projects/server/synapse), [Github](https://github.com/matrix-org/synapse), [Installation and configuration](https://matrix-org.github.io/synapse/latest/setup/installation.html)          |
| Syncthing               | ✅            | `linuxserver/syncthing`                      | P2P file synchronization daemon.                               | [Website](https://syncthing.net), [Github](https://github.com/syncthing/syncthing)                                                                                                                                          |
| Telegram RSS Bot        | ✅            | `miroslavsckaya/tg-rss-bot`                  | Telegram RSS Bot by @Miroslavsckaya.                           | [Gitea](https://git.skobk.in/Miroslavsckaya/tg_rss_bot/), [Github Mirror](https://github.com/Miroslavsckaya/tg_rss_bot)                                                                                                     |
| Tor OBFS4 Bridge        | ✅            | `thetorproject/obfs4-bridge`                 | Tor OBFS4 Bridge for Tor blocking bypass.                      | [Website](https://community.torproject.org/relay/setup/bridge/), [Gitlab](https://gitlab.torproject.org/tpo/anti-censorship/docker-obfs4-bridge), [Manual](https://community.torproject.org/relay/setup/bridge/docker/)     |
| Tor Privoxy             | ✅            | `registry.gitlab.com/skobkin/torproxy-obfs4` | Tor image with integrated privoxy and OBFS4 bridge support.    | [Original image Github](https://github.com/dperson/torproxy), [OBFS4 support image Gitlab](https://gitlab.com/skobkin/torproxy-obfs4)                                                                                       |
| Watchtower              | ✅            | `containrrr/watchtower`                      | Docker container auto-update daemon.                           | [Website](https://containrrr.dev/watchtower/), [Github](https://github.com/containrrr/watchtower)                                                                                                                           |
| Wireguard               | ❌ Unfinished | `cmulk/wireguard-docker`                     | WireGuard VPN.                                                 | [Website](https://www.wireguard.com), [Image Github](https://github.com/cmulk/wireguard-docker)                                                                                                                             |
| ~~Wordpress~~           | ❌ Unfinished | `wordpress`                                  | Wordpress blogging platform.                                   | [Webiste](https://wordpress.org), [SVN](https://build.trac.wordpress.org/browser)                                                                                                                                           |
