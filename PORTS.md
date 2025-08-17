# Docker Stacks Port Documentation

This document tracks all exposed ports across Docker stacks to prevent conflicts during deployment.

## All Exposed Ports

| Stack | Service | Default Host Port | Container Port | Is HTTP | Protocol | Notes |
|-------|---------|-------------------|----------------|---------|----------|-------|
| ark-server | server | 7777 | 7777 | ❌ | TCP/UDP | Game server |
| ark-server | server | varies | varies | ❌ | TCP/UDP | Query/RCON ports |
| castopod | castopod | 8393 | 8000 | ✅ | TCP | Podcast hosting |
| drone | drone | 8386 | 80 | ✅ | TCP | CI/CD server |
| drone-runner | drone-runner | 8387 | 3000 | ✅ | TCP | CI/CD runner |
| duplicati | duplicati | 8200 | 8200 | ✅ | TCP | Backup software |
| element-web | element-web | varies | 80 | ✅ | TCP | Matrix client |
| emby | emby | 8096 | 8096 | ✅ | TCP | Media server |
| faster-whisper | faster-whisper | 10300 | 10300 | ✅ | TCP | Speech-to-text API |
| firefly-iii | firefly-iii | 8392 | 8080 | ✅ | TCP | Personal finance |
| folding-at-home | foldingathome | varies | 7396 | ✅ | TCP | Distributed computing |
| forgejo | forgejo | 3000 | 3000 | ✅ | TCP | Git hosting |
| forgejo | server | 222 | 22 | ❌ | TCP | SSH Git access |
| gatus | gatus | 8080 | 8080 | ✅ | TCP | Status page |
| gotosocial | gotosocial | 8080 | 8080 | ✅ | TCP | Mastodon-compatible |
| hedgedoc | hedgedoc | 8394 | 8394 | ✅ | TCP | Collaborative editor |
| home-assistant | homeassistant | *host mode* | *host mode* | ✅ | - | IoT hub |
| homer | homer | 8084 | 8080 | ✅ | TCP | Dashboard |
| i2pd | i2pd | 7070 | 7070 | ✅ | TCP | Web interface |
| i2pd | i2pd | 4444 | 4444 | ❌ | TCP | HTTP proxy |
| i2pd | i2pd | 4447 | 4447 | ❌ | TCP | SOCKS proxy |
| i2pd | i2pd | 7656 | 7656 | ❌ | TCP | SAM bridge |
| i2pd | i2pd | 7654 | 7654 | ❌ | TCP | I2CP server |
| i2pd | i2pd | 7650 | 7650 | ❌ | TCP | I2P control |
| immich | immich-server | 2283 | 2283 | ✅ | TCP | Photo management |
| inbucket | inbucket | 8389 | 9000 | ✅ | TCP | Email testing |
| inbucket | inbucket | 8389 | 2500 | ❌ | TCP | SMTP server |
| inbucket | inbucket | 8389 | 1100 | ❌ | TCP | POP3 server |
| kf2-server | kf2-server | 8080 | 8080 | ✅ | TCP | Web admin |
| kf2-server | kf2-server | 7777 | 7777 | ❌ | UDP | Game port |
| kf2-server | kf2-server | 20560 | 20560 | ❌ | UDP | Query port |
| kf2-server | kf2-server | 27015 | 27015 | ❌ | UDP | Steam port |
| lidarr | lidarr | varies | 8686 | ✅ | TCP | Music management |
| magnetico-web | magnetico-web | 8080 | 80 | ✅ | TCP | Torrent search |
| magneticod | magneticod | varies | varies | ❌ | UDP | DHT crawler |
| mastodon-fe-gts | masto-fe | 8398 | 80 | ✅ | TCP | Mastodon frontend |
| meshtastic-web | meshtastic-web | 8397 | 8080 | ✅ | TCP | LoRa mesh UI |
| metube | metube | 8081 | 8081 | ✅ | TCP | YouTube downloader |
| mosquitto | mosquitto | 1883 | 1883 | ❌ | TCP | MQTT broker |
| mosquitto | mosquitto | 1884 | 1884 | ❌ | TCP | WebSocket |
| murmur | murmur | 64738 | 64738 | ❌ | TCP/UDP | Voice chat |
| ollama | webui | 3000 | 8080 | ✅ | TCP | AI chat interface |
| ollama | ollama | 11434 | 11434 | ✅ | TCP | AI API server |
| openhands | openhands | 3000 | 3000 | ✅ | TCP | AI coding assistant |
| open-streaming-platform | osp | 8585 | 80 | ✅ | TCP | Live streaming |
| open-streaming-platform | osp | 8553 | 443 | ✅ | TCP | HTTPS |
| open-streaming-platform | osp | 1935 | 1935 | ❌ | TCP | RTMP streaming |
| openvpn | openvpn | 1194 | 1194 | ❌ | UDP | VPN server |
| owncast | owncast | varies | 8080 | ✅ | TCP | Live streaming |
| piper | piper | 10200 | 10200 | ✅ | TCP | Text-to-speech |
| portainer | portainer | 9000 | 9000 | ✅ | TCP | Docker management |
| proxy-mtproto | proxy | varies | varies | ❌ | TCP | Telegram proxy |
| proxy-socks5 | proxy | 2080 | 1080 | ❌ | TCP | SOCKS5 proxy |
| qbittorrent | qbittorrent | varies | varies | ✅ | TCP | Torrent client web UI |
| qbittorrent | qbittorrent | 6881 | 6881 | ❌ | TCP/UDP | BitTorrent |
| radarr | radarr | varies | 7878 | ✅ | TCP | Movie management |
| redis | redis | 6379 | 6379 | ❌ | TCP | Database |
| shinobi | shinobi | varies | 8080 | ✅ | TCP | Video surveillance |
| sish | sish | 8395 | 8395 | ✅ | TCP | HTTP tunneling |
| sish | sish | 2222 | 2222 | ❌ | TCP | SSH tunneling |
| sonarr | sonarr | varies | 8989 | ✅ | TCP | TV show management |
| speedtest | speedtest | 8888 | 80 | ✅ | TCP | Internet speed test |
| synapse | synapse | 8008 | 8008 | ✅ | TCP | Matrix server |
| synapse | sliding-sync | 8889 | 8889 | ✅ | TCP | Matrix sync proxy |
| syncthing | syncthing | varies | 8384 | ✅ | TCP | File sync UI |
| syncthing | syncthing | 22000 | 22000 | ❌ | TCP/UDP | File sync |
| syncthing | syncthing | 21027 | 21027 | ❌ | UDP | Discovery |
| tor-obfs4-bridge | tor | varies | varies | ❌ | TCP | Tor bridge |
| tor-privoxy | tor | 8118 | 8118 | ❌ | TCP | HTTP proxy |
| tor-privoxy | tor | 9050 | 9050 | ❌ | TCP | SOCKS proxy |
| tor-privoxy | tor | 9040 | 9040 | ❌ | TCP | Transparent proxy |
| tor-privoxy | tor | 5353 | 5353 | ❌ | TCP | DNS |
| transmission | transmission | 9091 | 9091 | ✅ | TCP | Torrent client |
| transmission | transmission | 51413 | 51413 | ❌ | TCP/UDP | BitTorrent |
| v2fly-client | v2fly | 1050 | 1050 | ❌ | TCP | SOCKS proxy |
| v2fly-client | v2fly | 1080 | 1080 | ❌ | TCP | HTTP proxy |
| v2fly-client | v2fly | 12345 | 12345 | ❌ | TCP/UDP | Transparent proxy |
| webhooksite | webhook | varies | 80 | ✅ | TCP | Webhook testing |
| webhooksite | echo-server | 6001 | 6001 | ❌ | TCP | Echo server |

## Notes for Stack Creators

1. **Check this file** before assigning default ports to new stacks
2. **Use environment variables** for all port configurations
3. **Default to localhost binding** (`127.0.0.1`) for security
4. **Update this file** when creating or modifying stacks
5. **Test for conflicts** before deploying multiple stacks

## Quick Conflict Check

Before starting multiple stacks, verify no port conflicts exist:

```bash
# Check currently used ports
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Check if port is in use
netstat -tulpn | grep :PORT_NUMBER
```