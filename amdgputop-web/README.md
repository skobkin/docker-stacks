# amdgputop-web

Read-only web UI for live AMD GPU telemetry. See the [upstream documentation](https://github.com/skobkin/amdgputop-web)
for feature details and the full list of environment variables.

## Setup

Copy `.env.dist` to `.env` and review optional application settings or GPU
device paths. If GPU model names are missing inside the container, uncomment
`COMPOSE_FILE=docker-compose.yml:docker-compose.hwdata.yml` and optionally
adjust `PCI_IDS_PATH` to mount the host `pci.ids` database. By default there is
no extra mount, so the image uses its own bundled PCI database.

To enable host process telemetry, define `VIDEO_GROUP_ID` and
`RENDER_GROUP_ID` using the host group IDs (for example `getent group video`)
and uncomment the `devices`, `group_add`, `pid`, `cap_add`, and `user`
sections in `docker-compose.yml`.
