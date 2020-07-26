# Wireguard VPN

![Wireguard Logo](https://www.wireguard.com/img/wireguard.svg)

## Basic configuration

### Create config files

```shell
cp examples/server/wg0.conf.dist config/wg0.conf
```

You can edit configuration according to your needs.

### Generate keys

Don't forget to set public and private keys for the server and client!

To get the keys you can use `genkeys` command:

```shell
docker-compose run wireguard genkeys
```

Output example:

```
Private Key:    aAaAAaaaAAaa+AAaAaAaAA1aa/aaAA1aaaaAa1aaaA1=
Public Key:     /11a1aAaA1a/AAa11AAaa1AAa/AaAA1a1aaa11/AaAa=
```

Not you can use these keys in your configuration file.

## Additional requirements

### Kernel module

You need to be sure that [Wireguard](https://www.wireguard.com/install/) kernel module is installed on the host system.

#### Ubuntu / Debian

For kernel versions [older than 5.6](https://www.phoronix.com/scan.php?page=news_item&px=Linux-5.6-Released):

```shell
apt-get install -y --no-install-recommends wireguard-dkms
```

### See also

You can also check Docker image instructions [here](https://hub.docker.com/r/cmulk/wireguard-docker).