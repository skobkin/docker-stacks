# `logging` Network

A dedicated Docker bridge network used by the [`victoria-logs`](../victoria-logs)
and [`fluent-bit`](../fluent-bit) stacks when deployed on the same host.
It lets fluent-bit reach VictoriaLogs via Docker DNS at the address
`victoria-logs:9428`.

## Creating the Network

To create the network, run the following command:

```shell
docker network create logging
```

## Verifying the Network

You can verify that the network was created successfully by running:

```shell
docker network ls | grep logging
```

## Using the Network

The `victoria-logs` stack joins it on every variant. The `fluent-bit`
stack joins it on the `default` variant only.

Operators running fluent-bit on a different host (using
`COMPOSE_VARIANT=remote` in [`fluent-bit`](../fluent-bit/.env.dist))
do not need to create this network on the remote host — fluent-bit
reaches the remote VictoriaLogs over the LAN instead.

## Troubleshooting

If you see an error like:

```
network logging declared as external, but could not be found
```

This means you need to create the network first using the command above.