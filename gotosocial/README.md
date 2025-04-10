# GoToSocial

## System requirements and deploy considerations

> You can find more detail on system requirements below, but in short you should aim to have a system with at least 1 CPU core, about 1GB of memory (maybe more depending on your operating system), and 15GB-20GB of storage space (for the first few years).

For more details check the [docs](https://docs.gotosocial.org/en/latest/getting_started/).

## Configuration

Official configuration example provided here: [`config.yaml`](https://raw.githubusercontent.com/superseriousbusiness/gotosocial/refs/heads/main/example/config.yaml).

### Important note

DO NOT run your server before you configured the `host` in `config/config.yaml` first. If you're planning to use split domain option, then you need to also configure `account-domain` first.

Otherwise your setup will be broken.

### More useful links

- [Configuration overview](https://docs.gotosocial.org/en/latest/configuration/#environment-variables)
- [Using environment variables](https://docs.gotosocial.org/en/latest/configuration/#environment-variables)
- [Container deployment](https://docs.gotosocial.org/en/latest/getting_started/installation/container/)
- [Email configuration](https://docs.gotosocial.org/en/latest/configuration/smtp/)
- [Media caching](https://docs.gotosocial.org/en/latest/admin/media_caching/)
- [Storage](https://docs.gotosocial.org/en/latest/configuration/storage/) (S3 supported)
- [Rate limiting](https://docs.gotosocial.org/en/latest/api/ratelimiting/)

## Using CLI

Full documentation is [here](https://docs.gotosocial.org/en/latest/admin/cli/).

### Creating users (when registration is closed)

```shell
docker compose exec gotosocial /gotosocial/gotosocial admin account create --username some_username --email someone@example.org --password 'some_very_good_password'
```

For more details check the [docs](https://docs.gotosocial.org/en/latest/getting_started/user_creation/)
