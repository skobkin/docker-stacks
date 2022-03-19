# Using database on host machine from Docker


## Database configuration

### PostgreSQL
You need to make PostgreSQL listen not only `localhost`, but also Docker's network interface.

To do that you need to add host machine IP address in the Docker network (usually `172.17.0.1`) to the
`postgresql.conf` by changing `listen_addresses` parameter:
```ini
# Listen local interface and also Docker's network
listen_addresses = 'localhost,172.17.0.1'
```

Then you need to allow apps inside Docker containers to authenticate. That could be done by adding following line to the
`pg_hba.conf`:
```
# Docker network
host    all             all             172.17.0.0/12            md5
```

Do not forget to restart your PostgreSQL server. For PostgreSQL 12 and `main` cluster it could be usually done like that:

```shell
systemctl restart postgresql@12-main.service
```

### MySQL / MariaDB

TBW

## Application configuration inside Docker

Stacks which allow to use external database back-end should also map `host.docker.internal` to the host machine
address inside Docker's default network.

So to connect to the database from the application inside the container you should use `host.docker.internal` as the
database host/address.
