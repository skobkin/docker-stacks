# `databases` Network

Some database-backed services in this repository use an external Docker network called `databases`. This network lets application containers reach shared database containers by service or container name without exposing database ports on the host.

## Creating the Network

```shell
docker network create databases
```

## Verifying the Network

```shell
docker network ls | grep databases
```

## Using the Network

The network is configured in the docker-compose files of services that require it. Create the network before starting those stacks, and attach any shared database containers that should be reachable from them.

## Troubleshooting

If Compose reports `network databases declared as external, but could not be found`, create it first with the command above.
