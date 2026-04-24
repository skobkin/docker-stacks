# Beszel Hub

This stack runs `henrygd/beszel` (Hub + UI).

## Traefik

Optional Traefik support uses the simple `COMPOSE_VARIANT` pattern from other stacks in this repo.

Set `COMPOSE_VARIANT=traefik`, make sure the external Docker network from `TRAEFIK_NETWORK` exists, and set `TRAEFIK_HOST` to the hostname Traefik should serve for Beszel.

Keep `APP_URL` aligned with the externally served Beszel URL when you use Traefik, for example `https://beszel.example.com`.

Beszel uses WebSocket connections through the same hostname, so avoid reverse-proxy settings that break `Upgrade` handling.

## Reset Password (Short)

If you lose access, reset the PocketBase superuser password from the container:

```bash
docker exec beszel /beszel superuser upsert name@example.com new_password
```

Notes:

- This resets only the PocketBase admin login (`/_/`), not the Hub user password.
- After logging into `/_/`, update Hub account passwords in the `users` collection.
- Show all available options:

```bash
docker exec beszel /beszel superuser --help
```

Reference: https://beszel.dev/guide/user-accounts#reset-password
