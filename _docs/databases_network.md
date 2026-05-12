# `databases` Network

Some database-backed services in this repository can use an external Docker network called `databases`.

This network lets application containers reach PostgreSQL, MySQL, or MariaDB running directly on the Docker host, or shared database containers attached to the same external network.

## Creating the Network

For bare-metal databases on the Docker host, prefer a fixed subnet and gateway so the database can listen on a stable host-side bridge IP:

```shell
docker network create --subnet 10.10.10.0/24 --gateway 10.10.10.1 databases
```

If you only use shared database containers and do not need a stable host-side bridge IP, a plain network is enough:

```shell
docker network create databases
```

## Verifying the Network

```shell
docker network ls | grep databases
```

## Using the Network

Stacks that support this optional network use the same feature-variant pattern as Traefik:

- `COMPOSE_VARIANT=databases` attaches the application container to the shared database network.
- `COMPOSE_VARIANT=traefik_databases` combines Traefik routing and shared database networking when a stack supports both.
- `DATABASES_NETWORK=databases` controls the external Docker network name.

Create the network before starting those stacks.

For a database running directly on the Docker host, configure the stack database host or DSN to use the network gateway IP, for example `172.30.10.1`.

For shared database containers, attach the database container to this network and configure the stack database host or DSN to use the database container name on the shared network.

## Host Database Configuration

### PostgreSQL

Make PostgreSQL listen on the host-side gateway IP of the `databases` network. With the example network above, add the gateway IP to `listen_addresses` in `postgresql.conf`:

```ini
listen_addresses = 'localhost,172.30.10.1'
```

Allow connections from containers on the `databases` network in `pg_hba.conf`:

```text
host    all             all             172.30.10.0/24            scram-sha-256
```

Restart PostgreSQL after changing these files.

### MySQL / MariaDB

Make MySQL or MariaDB listen on the host-side gateway IP of the `databases` network. With the example network above, set `bind-address` in the server config:

```ini
bind-address = 172.30.10.1
```

Grant application users from the Docker network subnet, or from the specific container addresses if you assign static IPs. For example:

```sql
CREATE USER 'app'@'172.30.10.%' IDENTIFIED BY 'change-me';
GRANT ALL PRIVILEGES ON app.* TO 'app'@'172.30.10.%';
FLUSH PRIVILEGES;
```

Restart MySQL or MariaDB after changing the listener configuration.

## Notes

The older `host.docker.internal` approach can still work for stacks that map `host.docker.internal:host-gateway`, but the `databases` network with a fixed gateway IP is preferred for database access because it is explicit and can be firewalled separately from Docker's default bridge network.

## Troubleshooting

If Compose reports `network databases declared as external, but could not be found`, create it first with the command above.
