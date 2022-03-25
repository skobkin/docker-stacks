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
