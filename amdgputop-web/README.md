# amdgputop-web

Read-only web UI for live AMD GPU telemetry. See the [upstream documentation](https://github.com/skobkin/amdgputop-web)
for feature details and the full list of environment variables.

## Setup

Copy `.env.dist` to `.env` and review optional application settings or GPU
device paths.

The image bundles Alpine's `hwdata-pci` package (`/usr/share/hwdata/pci.ids`),
so GPU model names resolve inside the container without any extra volume mount.

To override the bundled PCI database with the host's copy (for example, a more
recent `pci.ids` than the one shipped in the image), set
`COMPOSE_FILE=docker-compose.yml:docker-compose.hwdata.yml` and adjust
`PCI_IDS_PATH` if the host file lives outside `/usr/share/hwdata/`.

To enable host process telemetry, define `VIDEO_GROUP_ID` and
`RENDER_GROUP_ID` using the host group IDs (for example `getent group video`)
and uncomment the `devices`, `group_add`, `pid`, `cap_add`, and `user`
sections in `docker-compose.yml`.
