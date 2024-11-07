# Usage

## Configuration

```shell
cp config/files/acls.dist config/files/acls
cp config/files/passwords.dist config/files/passwords
cp config/files/passwords.dist config/files/passwords
cp config/mosquitto.conf.dist config/mosquitto.conf
```

Edit configuration to suit your needs.

## Passwords

To generate password hashes, you can use `pw` tool located at the `/mosquitto/pw` inside the container.

```shell
docker compose exec mosquitto sh
/mosquitto/pw --help
/mosquitto/pw -p MyPasswordString
```

## ACL's

Refer to the [documentation](https://github.com/iegomez/mosquitto-go-auth?tab=readme-ov-file#acl-file).
