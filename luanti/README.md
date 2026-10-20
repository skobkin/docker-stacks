# Luanti (formerly Minetest) dedicated server

Self-hosted [Luanti](https://www.luanti.org) server able to run either of the two popular Minecraft-like survival games:

| Game | Game ID | Upstream | License |
|------|---------|----------|---------|
| [VoxeLibre](https://content.luanti.org/packages/wuzzy/mineclone2/) | `voxelibre` | [git.minetest.land/VoxeLibre/VoxeLibre](https://git.minetest.land/VoxeLibre/VoxeLibre) | GPL-3.0 / CC-BY-SA-4.0 |
| [Mineclonia](https://content.luanti.org/packages/ryvnf/mineclonia/) | `mineclonia` | [codeberg.org/mineclonia/mineclonia](https://codeberg.org/mineclonia/mineclonia) | GPL-3.0 / CC-BY-SA-4.0 |

Both games require Luanti **5.10 or newer**. This stack uses the official [`ghcr.io/luanti-org/luanti`](https://docs.luanti.org/for-server-hosts/setup/containers/) image, which runs as user `minetest` (UID/GID `30000`) and speaks Luanti's own UDP protocol on port `30000` — HTTP reverse proxies are not involved (see [Networking](#networking)).

## Quick start (VoxeLibre)

```shell
# Enter the stack directory
cd luanti

# Create the environment file and the server configuration
cp .env.dist .env
nano -w .env
cp config/minetest.conf.dist config/minetest.conf
nano -w config/minetest.conf   # set the join password and your admin name!

# The container writes worlds/players/auth data as UID/GID 30000.
# data/.minetest must exist before the first start (the server opens its
# debug log there and will not create the directory itself).
mkdir -p data/.minetest
sudo chown -R 30000:30000 data

# Install the game (choose VoxeLibre, accept the suggested version)
./install-game.sh

# Start the server
docker compose up -d
docker compose logs -f
```

A world named after `WORLD_NAME` (default `world`) is created automatically on first start under `data/.minetest/worlds/` and permanently bound to `GAME_ID`. Players can then connect with a Luanti client to `<server-ip>:30000` — the join password from `minetest.conf` is required when registering a new account.

## Installing games

Games live under the directory configured in `HOST_GAMES_DIR` (default `./games`), one subdirectory per game named after its game ID. Both games can be installed side by side; selection happens in `.env`, not by reinstalling anything.

### Easy way: `./install-game.sh`

The helper script:

1. Warns and exits if `.env` does not exist (create it with `cp .env.dist .env` first).
2. Asks which game to install (marks the one currently selected via `GAME_ID`).
3. Offers the latest upstream release tag (you can type an older tag to pin or roll back).
4. Shows the resolved game, version and target path, and asks for confirmation.
5. Clones the game at that tag into `$HOST_GAMES_DIR/<game-id>` — or, if it is already installed, fetches and checks out the chosen tag (this is how updates and rollbacks are done; it refuses to touch a directory that is not a git clone of the same repository).

Manual updates/rollbacks work the same way without the script:

```shell
git -C games/voxelibre fetch --force --depth 1 origin tag 0.92.2
git -C games/voxelibre checkout 0.92.2
docker compose restart luanti
```

Games are updated independently of the Luanti engine (which is updated via `IMAGE_TAG`) and are re-downloadable at any time — never back them up from scratch, but do back up worlds (see [Backups](#backups-and-restore)).

### Manual installation

```shell
# VoxeLibre (primary upstream; ContentDB package: wuzzy/mineclone2)
git clone --branch 0.92.4 --depth 1 \
  https://git.minetest.land/VoxeLibre/VoxeLibre.git games/voxelibre

# Mineclonia (primary upstream; ContentDB package: ryvnf/mineclonia)
git clone --branch 0.124.0 --depth 1 \
  https://codeberg.org/mineclonia/mineclonia.git games/mineclonia
```

Clone into the exact directory names shown (`voxelibre`, `mineclonia`) — Luanti uses the directory name as the game ID. Pin a released tag rather than tracking the development branch. Check the game's project page for the minimum supported engine version before major upgrades of either side.

Verify what the server sees:

```shell
docker compose exec luanti luantiserver --gameid list
```

### Selecting a game

```shell
# .env
GAME_ID=voxelibre    # or mineclonia
WORLD_NAME=world     # name of the world directory to serve
```

## Games and worlds

A world is a directory under `data/.minetest/worlds/` (or your `HOST_DATA_DIR`). Every world permanently records the game it was created with in its `world.mt` file (`gameid=...`).

- **Game selection vs. world selection are two separate things.** `GAME_ID` only tells the engine which game to load; `WORLD_NAME` selects the world directory.
- **Changing `GAME_ID` alone does not switch an existing world.** Worse: the command-line `--gameid` overrides the game recorded in `world.mt`, so pointing a different game at an existing world makes the engine load the wrong game into it, which can corrupt the world. Always keep `GAME_ID` and `WORLD_NAME` a consistent pair.
- **To run both games**, give each its own world and switch the pair together:

  ```shell
  # Playing VoxeLibre
  GAME_ID=voxelibre
  WORLD_NAME=voxelibre

  # Playing Mineclonia
  GAME_ID=mineclonia
  WORLD_NAME=mineclonia
  ```

  Then `docker compose up -d` after each change (the container restarts with the other world). Only one world is served at a time; both progress independently and safely.
- **No automatic conversion between VoxeLibre and Mineclonia exists or is performed here.** Copying a world between the two games is an advanced, potentially destructive experiment — back up the world first and never copy over the original.

## Running and monitoring

```shell
docker compose up -d            # start (creates a new world on first start)
docker compose stop             # stop gracefully
docker compose restart luanti   # restart
docker compose down             # stop and remove the container (data is kept)
docker compose logs -f          # follow logs
```

First start creates the world; look for game/mod loading lines (`mcl_*` mods belong to both Minecraft-like games) to confirm the expected game loaded. Useful checks:

```shell
docker compose exec luanti luantiserver --version        # engine version
docker compose exec luanti luantiserver --gameid list    # installed games
docker compose exec luanti luantiserver --worldlist name # known worlds
```

Recreating the container (`docker compose up -d` after config changes) preserves worlds, players and accounts — everything persists under `HOST_DATA_DIR`.

## Server configuration

`config/minetest.conf.dist` is a minimal template for a small private survival server (10 players, damage on, PvP off, hidden from the public list). Copy it to `config/minetest.conf`, edit, then `docker compose restart luanti`. The full option reference for your engine version is [minetest.conf.example](https://github.com/luanti-org/luanti/blob/5.17.0/minetest.conf.example).

Key settings:

- `default_password` — shared password every new player must enter to register (see below).
- `name` — your player name; connecting with it makes you the server admin.
- `server_announce = false` — keeps the server off the public server list (not an access control).
- `enable_damage`, `enable_pvp`, `max_users`, `motd`, `server_name`, `server_description`.

## Passwords, accounts and access

**Protecting the server (default setup):** set `default_password` in `config/minetest.conf` to a secret you share with friends. Any player registering a new account must enter it; afterwards they log in with their own personal password. Change the placeholder before exposing the server to the internet.

**Fully public server:** comment out or empty `default_password` — anyone who discovers the address can register.

**Accounts:**

- *Admin:* set `name = YourName` in `minetest.conf` and connect with exactly that player name. The first connection registers the account (enter the join password when prompted) and it automatically receives all admin privileges. Grant privileges to others in-game with `/grant <player> <privs>` or `/grantme` as admin.
- *Regular players:* connect with a new player name, enter the join password once at registration, choose a personal password, and they get the default privileges (`interact`, `shout`).

Note the distinction: `server_announce = false` only hides the server from the public list; the join password only gates account registration; neither restricts who can attempt to reach the server on the network (see below).

## Security

Three different layers, often confused:

1. **Visibility:** `server_announce = false` keeps the server out of `servers.luanti.org`. Anyone who learns the address can still try to connect.
2. **Authentication:** `default_password` gates new account registration; registered players authenticate with their personal passwords. This is the main practical gate for a friends-only server. It does not restrict the network in any way.
3. **Network access control:** only a firewall, VPN, or the bind address actually limit which hosts can reach UDP 30000. For a strictly private server, prefer keeping it behind a VPN (WireGuard, ZeroTier) or firewalling the port to known IPs.

Luanti's game protocol does not provide end-to-end encryption of game traffic like a HTTPS connection would; keep that in mind for fully public servers. Per-user or per-network whitelisting is possible via third-party whitelist mods, which this stack intentionally does not install by default.

## Networking

Clients speak Luanti's own protocol over **UDP port 30000** (`BIND_PORT`), so HTTP reverse proxies such as Traefik or Nginx are irrelevant here — the stack publishes the UDP port directly, bound to `BIND_ADDRESS` (default `0.0.0.0`, i.e. all interfaces).

- **LAN:** clients connect to the host's LAN IP, port 30000. No forwarding needed.
- **VPN (WireGuard/ZeroTier):** connect to the server's VPN IP. Nothing extra to configure if the VPN interface is reachable (`0.0.0.0` binding covers it).
- **Public internet:** forward **UDP 30000** on your router to the Docker host, then share your public IP or hostname.
- **Linux firewall example:** `sudo ufw allow 30000/udp` (or the equivalent nftables/iptables rule for `BIND_PORT`).

Host networking is not required — ordinary Docker port publishing works fine for this protocol.

## Backups and restore

Persistent data layout (host paths configurable via `.env`):

| Path | Contains |
|------|----------|
| `data/` (`HOST_DATA_DIR`) | Worlds (`data/.minetest/worlds/`), player inventory, accounts/auth — **the only irreplaceable data** |
| `config/minetest.conf` (`HOST_CONFIG_DIR`) | Server configuration (recreatable, but contains your chosen secrets) |
| `games/` (`HOST_GAMES_DIR`) | Game installations — re-downloadable, no backup needed |
| `mods/` (`HOST_MODS_DIR`) | Optional mods — re-downloadable, no backup needed |

Worlds are stored in SQLite databases. **Copying a live world can produce a corrupt or inconsistent backup**, because the server may be mid-write. Always stop the server first:

```shell
docker compose stop
tar -czf luanti-backup-$(date +%F).tar.gz data config/minetest.conf
docker compose start
```

Restore (on a fresh host or after data loss):

```shell
cd luanti
cp .env.dist .env && nano -w .env            # same GAME_ID/WORLD_NAME pair as before!
sudo chown -R 30000:30000 data
tar -xzf luanti-backup-YYYY-MM-DD.tar.gz
docker compose up -d
```

Games and mods do not need restoring — reinstall them with `./install-game.sh` or a fresh `git clone`.

## Updates and maintenance

Four independent update paths — all explicit, none happen automatically on container restart:

1. **Luanti engine:** change `IMAGE_TAG` in `.env` (e.g. `5.17` already tracks new `5.17.x` releases; bump to `5.18` for a new stable line), then `docker compose up -d`. Check both games' minimum engine requirements first.
2. **VoxeLibre:** `./install-game.sh` → choose `voxelibre` → accept the new version (or type a tag).
3. **Mineclonia:** `./install-game.sh` → choose `mineclonia` → accept the new version.
4. **Mods:** replace/checkout the mod under `mods/`, then restart.

**Before a major update** (new engine stable line or a big game version jump): back up `data/` as shown above. **Rollback:** reinstall the previous game tag (`./install-game.sh`, type the old version) and/or pin the previous `IMAGE_TAG`, then `docker compose up -d`. If a game update migrated the world format, roll back from the backup instead of re-running the old version on a migrated world.

## Client connection

Players need the [Luanti client](https://www.luanti.org/downloads/) — available for **Linux** (Flatpak, AppImage, distro packages), **Windows** (installer on the downloads page), and **Android** (Google Play, F-Droid).

1. Install and start the Luanti client.
2. *Join Game* tab → enter the server address (`<server-ip>` or hostname) and port `30000`.
3. Enter a player name; new accounts are asked for the join password (`default_password`), then set a personal password.

Clients do **not** need VoxeLibre or Mineclonia installed — the server sends all game content automatically. **Ordinary Minecraft Java or Bedrock clients cannot connect**; these games are compatible in gameplay, not in protocol.
