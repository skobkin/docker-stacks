# amdgputop-web

Read-only web UI for live AMD GPU telemetry. See the [upstream documentation](https://github.com/skobkin/amdgputop-web)
for feature details and the full list of environment variables.

## Setup

Review `.env` to adjust optional application settings or GPU device paths. To
enable host process telemetry, define `VIDEO_GROUP_ID` and `RENDER_GROUP_ID`
using the host group IDs (for example `getent group video`) and uncomment the
`devices`, `group_add`, `pid`, `cap_add`, and `user` sections in
`docker-compose.yml`.
