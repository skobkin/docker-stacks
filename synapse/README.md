# [Synapse](https://matrix.org/docs/projects/server/synapse) ([Matrix.org](https://matrix.org/) server)

# Generating server configuration

Do not forget to prepare `.env` file before running this.

```shell
docker-compose run synapse generate
```

After that you can edit `./data/homeserver.yaml` according to your needs.

If you want to use full-fledged PostgreSQL instead of SQLite, you can check [this documentation](https://github.com/matrix-org/synapse/blob/master/docs/postgres.md).

# Running the server

```shell
docker-compose up -d
```
