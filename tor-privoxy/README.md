# Installation

```shell
# Create config file
cp config/torrc.dist config/torrc

# Edit config
nano -w config/torrc

# Create ENV file
cp .env.dist .env

# Edit ENV file (if needed)
nano -w .env

# Run services using Docker Compose V1
docker-compose up -d

# Docker Compose V2
docker compose up -d
```

# Using Tor Bridges

Uncomment the `UseBridges` and `ClientTransportPlugin` directives in the `config/torrc`.

Go to [bridges.torproject.org](https://bridges.torproject.org/bridges?transport=obfs4) and get some bridges. If it's blocked, you can also use [Telegram Bot](https://t.me/GetBridgesBot) or write an email to `bridges@torproject.org`.

Add one `Bridge` directive for each bridge you've got like that:

If you've got two bridges:
```
obfs4 1.2.3.4:1234 ABCD cert=xxx
obfs4 2.3.4.5:2345 BCDE cert=yyy
```

Add this to your `config/torrc` (do not forget to replace with real bridge address):
```
Bridge obfs4 1.2.3.4:1234 ABCD cert=xxx
Bridge obfs4 2.3.4.5:2345 BCDE cert=yyy
```
