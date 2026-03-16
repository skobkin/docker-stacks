# Beszel Agent

This stack runs `henrygd/beszel-agent` in Docker with host networking and Docker socket access.

## Docker Monitoring Caveats

Monitoring the host from inside a container is always partial unless you expose host resources explicitly.

- Filesystem metrics: only mounted host paths are visible to the agent.
- Docker metrics: require access to Docker API socket (`/var/run/docker.sock` by default).
- Sensor/GPU/S.M.A.R.T. visibility: depends on passing device nodes into the container.
- Systemd service visibility: depends on exposing host systemd sockets.

How to handle this:

- Keep `network_mode: host` (already set) for accurate host-level networking.
- Use `EXTRA_MOUNT_1..5` for host paths/disks you want shown in Beszel.
- Pass GPU-related devices via `GPU_DEVICE_1..5` when GPU monitoring is needed.
- Pass disk controller devices via `SMART_DEVICE_1..20` for S.M.A.R.T. data.
- Keep `SYSTEMD_DBUS_SOCKET` mounted for systemd service monitoring.
- If a metric is missing, first check whether the relevant host path/device is mounted.

## Connection Modes: WebSocket vs SSH

Two connection models are supported:

- WebSocket (recommended):
  - `DISABLE_SSH=true` (default)
  - Agent connects out to `HUB_URL`
  - Uses `TOKEN` + `KEY` for registration/auth
  - No inbound port exposure on the agent host

- SSH listener mode:
  - `DISABLE_SSH=false`
  - Agent listens on `LISTEN` (default `45876`)
  - Hub connects to agent over SSH
  - Requires routing/firewall rules from hub to agent

In most home-lab and NAT setups, WebSocket mode is simpler and safer to operate.

## S.M.A.R.T.

S.M.A.R.T. collection requires `smartctl` inside the agent container.

- This stack defaults to `IMAGE_TAG=alpine` (includes `smartctl`).
- Pass SMART devices via `SMART_DEVICE_1..20`.
- Prefer controller paths (`/dev/sda`, `/dev/nvme0`) over partitions (`/dev/sda1`, `/dev/nvme0n1`).
- If there are problems with NVMe, map partition to controller target (example: `/dev/nvme0n1:/dev/nvme0`).

## Optional Directory and GPU Mounts

Optional mounts are predeclared in `docker-compose.yml`, so you can enable them in `.env` without editing compose.

- Extra directories/filesystems:
  - `EXTRA_MOUNT_1..5` for host paths
  - `EXTRA_MOUNT_1_LABEL..EXTRA_MOUNT_5_LABEL` for in-container label suffixes under `/extra-filesystems/`
  - Only label suffix is overridden (examples: `sdb1`, `sdc1__Media`)

- GPU devices:
  - `GPU_DEVICE_1..5`
  - Use host device paths (examples in `.env.dist`: `/dev/dri`, `/dev/kfd`, `/dev/nvidia0`, etc.)

- S.M.A.R.T. devices:
  - `SMART_DEVICE_1..20` and optional `SMART_DEVICE_*_MAPPED`
  - Use base controller names where possible (`/dev/sda`, `/dev/nvme0`), not partitions
  - For NVMe compatibility quirks, map host partition to controller path (for example `/dev/nvme0n1:/dev/nvme0`)
  - Compose already includes `SYS_RAWIO` and `SYS_ADMIN` capabilities required by Beszel docs for Docker S.M.A.R.T.
  - Use an agent image with `smartctl` available (for example `IMAGE_TAG=alpine`)

Unused optional mounts/devices fall back to `/dev/null`, so compose remains valid when they are not configured.

## Systemd Monitoring from Docker

This stack mounts `/var/run/dbus/system_bus_socket` by default via `SYSTEMD_DBUS_SOCKET`, which is required for systemd metrics in Docker mode.

- If services still do not appear, set `SYSTEMD_PRIVATE_SOCKET=/var/run/systemd/private`.
- If logs show AppArmor D-Bus denial errors, add this under the service in compose:

```yaml
security_opt:
  - apparmor:unconfined
```
