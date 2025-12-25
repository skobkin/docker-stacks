# `proxy` Network

Some AI-related services in this repository require an external Docker network called `proxy`. This network is used to
allow using stealth proxies when accessing outside world.

## Creating the Network

To create the network, run the following command:

```shell
docker network create proxy
```

## Verifying the Network

You can verify that the network was created successfully by running:

```shell
docker network ls | grep proxy
```

## Using the Network

The network is automatically configured in the docker-compose files of services that require it. You don't need to do anything special beyond creating the network.

## Troubleshooting

If you see an error like:
```
network proxy declared as external, but could not be found
```

This means you need to create the network first using the command above.
