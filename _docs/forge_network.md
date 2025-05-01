# `forge` Network

The `forge` network is used to allow communication between Forgejo and Woodpecker CI services.

## Creating the Network

To create the network, run the following command:

```shell
docker network create forge
```

## Verifying the Network

You can verify that the network was created successfully by running:

```shell
docker network ls | grep forge
```

If you need to specify a custom subnet for the network, you can use the `--subnet` flag:

```shell
docker network create --subnet=172.20.0.0/16 forge
```

## Using the Network

The network is automatically configured in the docker-compose files of services that require it. You don't need to do anything special beyond creating the network.

## Troubleshooting

If you see an error like:
```
network forge declared as external, but could not be found
```

This means you need to create the network first using the command above. 