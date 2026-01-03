# `forge` Network

Some developer stacks share an external Docker network called `forge`. It lets Forgejo and related services (e.g., Woodpecker CI) talk to each other without exposing extra ports.

## Creating the Network

```shell
docker network create forge
```

## Verifying the Network

```shell
docker network ls | grep forge
```

## Troubleshooting

If Compose reports `network forge declared as external, but could not be found`, create it first with the command above.
