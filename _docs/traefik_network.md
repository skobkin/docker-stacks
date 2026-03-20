# `traefik` Network

Some stacks in this repository require an external Docker network called `traefik`.

This network is used as a shared attachment point for Traefik and the application stacks routed through it, for example
Continuwuity.

## Creating the Network

To create the network, run the following command:

```shell
docker network create traefik
```

## Verifying the Network

You can verify that the network was created successfully by running:

```shell
docker network ls | grep traefik
```

## Using the Network

Stacks that require this network already declare it as an external network in their `docker-compose.yml` files.

You only need to create it once. After that, Traefik and any stack configured for Docker-internal reverse proxying can
share it.

## Troubleshooting

If you see an error like:
```
network traefik declared as external, but could not be found
```

This means you need to create the network first using the command above.
