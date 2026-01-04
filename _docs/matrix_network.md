# `matrix` Network

Some Matrix-related stacks in this repository share an external Docker network called `matrix`. It lets Synapse and related services (e.g., Element Call) talk to each other without exposing extra ports.

## Creating the Network

```shell
docker network create matrix
```

## Verifying the Network

```shell
docker network ls | grep matrix
```

## Troubleshooting

If Compose reports `network matrix declared as external, but could not be found`, create it first with the command above.
