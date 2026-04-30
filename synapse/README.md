# [Synapse](https://matrix.org/docs/projects/server/synapse) ([Matrix.org](https://matrix.org/) server)

## Create internal network for Matrix services

```shell
docker network create --internal matrix
```

## Generate server configuration

Do not forget to prepare `.env` file before running this.

```shell
docker-compose run synapse generate
```

After that you can edit `./data/homeserver.yaml` according to your needs.

If you want to use full-fledged PostgreSQL instead of SQLite, you can check
[this documentation](https://github.com/matrix-org/synapse/blob/master/docs/postgres.md).

To use PostgreSQL running on the host machine, use [this](../_docs/access_database_on_host_from_docker.md) configuration.

## Run the server

```shell
docker-compose up -d
```

## Optional Traefik

Set `COMPOSE_VARIANT=traefik` and `TRAEFIK_HOST` to expose the main Synapse homeserver through the shared Traefik stack.
The variant adds routers for both the normal `websecure` entrypoint and Matrix federation on `matrixfederation`.

The shared Traefik stack must publish the `matrixfederation` entrypoint on port `8448`.
Sliding sync (`matrix-ss`) is not exposed by this variant.

See the [common Traefik guide](../_docs/traefik.md).
