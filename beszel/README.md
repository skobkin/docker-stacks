# Beszel Hub

This stack runs `henrygd/beszel` (Hub + UI).

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
