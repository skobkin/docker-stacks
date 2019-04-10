# Installation

```shell
# Create config file
cp config/murmur.ini.dist config/murmur.ini

# Edit config
nano -w config/murmur.ini

# Create ENV file
cp .env.dist .env

# Edit ENV file (set server hostname)
nano -w .env

# Run services (you may want to setup SSL certificate before this)
docker-compose up -d
```

# Issue a cert

Use [acme.sh](https://acme.sh) for certificate retrieval.

```shell
# Create directory
mkdir /etc/ssl/${MURMUR_HOSTNAME}

# Issue a cert
acme.sh --issue --standalone -d ${MURMUR_HOSTNAME}

# Copy
acme.sh --install-cert -d ${MURMUR_HOSTNAME} --key-file /etc/ssl/${MURMUR_HOSTNAME}/domain.key --fullchain-file /etc/ssl/${MURMUR_HOSTNAME}/domain.crt --reloadcmd "docker restart murmur"
```
