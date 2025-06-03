## 2025-06 - Forgejo, Woodpecker CI, and Woodpecker Agent stacks

### Major Changes (Breaking Changes)
- Forgejo now requires an external Docker network (`forge`). You must create this network manually before starting the stack. See the new documentation in [_docs/forge_network.md](_docs/forge_network.md).
- The `network_mode: host` option was removed from Forgejo's configuration. The stack now uses the `forge` network instead.
- The `version` key was removed from the top of the `docker-compose.yml`, which may affect compatibility with some Docker Compose versions.
- The default database host for Forgejo changed from `db` (internal service) to `host.docker.internal`. Update your `.env` if you use a different database setup.

### Minor Changes (New Features)
- Added `Woodpecker CI` stack: lightweight CI/CD platform ([woodpecker](woodpecker)).
- Added `Woodpecker Agent` stack: agent for executing Woodpecker pipelines ([woodpecker-agent](woodpecker-agent)).
- Added documentation for the `forge` Docker network used by Forgejo and Woodpecker CI ([_docs/forge_network.md](_docs/forge_network.md)).
- Introduced `CHANGELOG.md` for documenting future changes and updates.     