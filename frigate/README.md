# Frigate

[Frigate](https://frigate.video/) is an NVR focused on local object detection for IP cameras.

## Storage layout

Frigate writes to several different locations inside the container:

- `/config` stores `config.yml`, `frigate.db`, and other small mutable files.
- `/media/frigate` stores recordings, snapshots/clips, and exports.
- `/tmp/cache` is used for short-lived recording segment cache and is mounted as `tmpfs`.

Recommended host layout:

- Put `HOST_CONFIG_DIR` on fast storage because it contains the main SQLite database.
- Put `HOST_MEDIA_DIR` on larger slower storage.
- Optionally put `HOST_DB_DIR` on a separate fast SSD/NVMe mount.

## Separate DB storage

The compose stack provides an optional extra mount for a dedicated DB path, but Frigate keeps the
database under `/config` by default. To actually separate DB storage, point Frigate's database path
in your `config.yml` to a file under `${DB_MOUNT_TARGET}` such as `/frigate-db/frigate.db`.

## AMD GPU support

The default image tag is `stable-rocm`.

- For AMD video decoding, keep `LIBVA_DRIVER_NAME=radeonsi`.
- For VAAPI decoding, pass `/dev/dri` via `DRI_DEVICE`.
- For ROCm-based features in the `stable-rocm` image, also pass `/dev/kfd` via `KFD_DEVICE` when needed.
- If you do not need GPU access, set `DRI_DEVICE=/dev/null` and `KFD_DEVICE=/dev/null` in your local `.env`.

## Notes

- Review `SHM_SIZE` if you use many cameras or higher resolutions. Frigate may fail with bus errors if shared
  memory is too small.
- The stack exposes Frigate UI/API on `8971` and restream ports `8554` and `8555` on localhost by default.
- The internal unauthenticated port `5000` is intentionally not published by default.
