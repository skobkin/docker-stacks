# OpenWebRX+

This stack runs OpenWebRX+ with Docker Compose defaults adapted from OpenWebRX Docker setup guidance.

## Notes

- Default image is `slechev/openwebrxplus-softmbe` (includes extra digital voice decoder support).
- OpenWebRX+ image set is not split by SDR hardware family, so AirSpy Mini works through default USB passthrough (`/dev/bus/usb`).
- Full image override is supported via `IMAGE_REPOSITORY` and `IMAGE_TAG` in `.env`.
- Timezone is configured deterministically via `TZ` only (no `/etc/localtime` bind mount).
- Main writable mounts are:
  - `HOST_ETC_DIR` -> `/etc/openwebrx`
  - `HOST_VAR_DIR` -> `/var/lib/openwebrx`
  - `HOST_PLUGINS_DIR` -> `/opt/openwebrx/plugins`
- `tmpfs` mount is enabled by default for temporary decoder files (`TMPFS_*` vars).

For general setup instructions, refer to the [root README](../README.md).
