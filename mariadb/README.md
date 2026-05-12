# MariaDB

Shared MariaDB server for stacks in this repository.

## Quick start

1. Copy `.env.dist` to `.env` and set `MARIADB_ROOT_PASSWORD` before first start.
2. If you want a default application database, uncomment and set `MARIADB_DATABASE`, `MARIADB_USER`, and `MARIADB_PASSWORD` before the first boot.
3. If you want local tuning or a different `bind-address`, copy `config/mariadb.cnf.dist` to `config/mariadb.cnf` and edit that file.
4. Start the stack with `docker compose up -d`.
5. Connect from the host at `127.0.0.1:3306` by default, or change `BIND_ADDR=0.0.0.0` if you intentionally want host-wide exposure.

## Shared databases network

This stack joins the external `databases` network. See the shared network guide in [_docs/databases_network.md](../_docs/databases_network.md) for setup and host-database examples.

Other stacks can connect to it as `mariadb:3306` when they are attached to the same network.

If you use the shared network for other database-backed stacks, keep the database host set to `mariadb` in their environment or DSN.

## Initial database setup

The bootstrap variables in `.env` only apply on first start with an empty data directory. For new applications, create a database and user manually after the container is up:

```sh
docker compose exec mariadb mariadb -uroot -p
```

```sql
CREATE DATABASE app_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'app_user'@'%' IDENTIFIED BY 'change-me';
GRANT ALL PRIVILEGES ON app_db.* TO 'app_user'@'%';
FLUSH PRIVILEGES;
```

Then point the application at:

- host: `mariadb`
- port: `3306`
- database: `app_db`
- user: `app_user`
- password: the password you created
