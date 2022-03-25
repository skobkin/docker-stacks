# Telegram Bridge for Matrix

## Create internal network for Matrix services

You should've created this network while setting up [synapse](../synapse/README.md). But if you didn't, then do it
before trying to run this stack:

```shell
docker network create --internal matrix
```

## Bridge setup documentation

- https://docs.mau.fi/bridges/python/setup/docker.html?bridge=telegram
  - https://docs.mau.fi/bridges/general/registering-appservices.html
- https://docs.mau.fi/bridges/python/telegram/relay-bot.html (optional)
