# Agent Guidelines for Docker Stacks

Keep this file repo-specific. Use general Docker/Compose best practices from normal engineering judgment; only rely on the rules below for conventions that matter in this repository.

## Core Rules

- Verify image tags, env var names, and app configuration against official docs, releases, or source. Do not guess versions or variable names.
- Prefer explicit stable image tags over `latest`. For mission-critical stacks such as `forgejo`, use a major-version tag when the image follows SemVer (for example `:12`) so `watchtower` can still apply compatible updates without pulling unexpected breaking changes.
- Use standard local directories when applicable: `./data`, `./config`, `./logs`, `./nginx`.
- Prefer generic variable names such as `IMAGE_TAG`, `HOST_DATA_DIR`, or `BIND_PORT` unless multiple services in the same stack need disambiguation.
- Parameterize host paths and ports in compose files and provide sane defaults with `${VAR:-default}`.
- Default published ports to localhost binding where appropriate and update [PORTS.md](PORTS.md) whenever exposed ports change.
- Use `env_file: .env` by default. Keep `.env.dist` in git, do not commit `.env` or secrets.
- Add concise comments to `.env.dist` for app-specific variables. Expand comments and add links only when an option is complex, non-obvious, or has dedicated upstream documentation.
- Keep per-stack `README.md` files focused on stack-specific behavior. When a section would duplicate guidance shared by multiple stacks, move that content into a common doc under [`_docs/`](./_docs/) and link to it from the stack README instead of repeating the full text.

## Compose Conventions

- Use `restart: unless-stopped` for most long-running services.
- Use the repo logging convention unless a stack has a strong reason not to:

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "${LOG_MAX_SIZE:-5m}"
    max-file: "${LOG_MAX_FILE:-5}"
```

- Use non-root execution, UID/GID mapping, LinuxServer `PUID`/`PGID`, and `/etc/localtime:/etc/localtime:ro` when the image supports those patterns.
- Use service-to-service communication over Docker networking. Do not use `host.docker.internal` when services can talk over a shared network.
- Add custom networks, `depends_on`, health checks, or extra config mounts only when they provide a clear benefit and the image supports them.

## Optional Traefik Support

- Do not make reverse proxy integration mandatory for every stack.
- When HTTP exposure through Traefik is appropriate, follow the existing optional pattern built around `extends`, optional external `traefik` network, and `COMPOSE_VARIANT=traefik`.
- Use existing stacks as references:
  `ip-detect` and `element-web` for simple optional Traefik support,
  `continuwuity` for a more advanced label/routing setup.
- When creating or changing a stack with optional Traefik support, clarify the expected behavior first:
  what should be exposed through Traefik, which entrypoint should be used (`web` for local HTTP-only setups or `websecure` for HTTPS/public exposure), how it should be configured, and whether the simple or advanced pattern fits better.
- When using the shared `websecure` entrypoint, do not add router-level TLS labels unless you intentionally need to override Traefik's entrypoint defaults such as ACME/certresolver behavior.

## Done Criteria

- `docker compose config` passes for the stack after preparing required local env files from tracked templates such as `.env.dist`.
- Tracked config templates and local ignore rules are required for mandatory user-edited files that are not reasonably created by the app on first start. If the app generates an acceptable initial config, document any first-run review or follow-up steps in the stack README when needed.
- Root `README.md` and [PORTS.md](PORTS.md) are updated when stack behavior or exposed ports change.
- Add a stack-local `README.md` only when the stack is complex, has prerequisites, needs post-install/manual steps, or requires external networking that is not obvious from the root docs.
