# `ai-tools` Network

Some AI-related services in this repository require an external Docker network called `ai-tools`. This network is used to allow communication between different AI services.

## Creating the Network

To create the network, run the following command:

```shell
docker network create ai-tools
```

## Verifying the Network

You can verify that the network was created successfully by running:

```shell
docker network ls | grep ai-tools
```

## Using the Network

The network is automatically configured in the docker-compose files of services that require it. You don't need to do anything special beyond creating the network.

## Troubleshooting

If you see an error like:
```
network ai-tools declared as external, but could not be found
```

This means you need to create the network first using the command above.
