# Agent Guidelines for Creating Docker Stacks

## Common Mistakes to Avoid

### Environment Variable Naming
**DO**:
- Use generic names like `IMAGE_TAG`
- Research actual documentation for variable names

**DON'T**:
- Use service name prefixes like `OPENHANDS_IMAGE_TAG` (unless multiple services in stack)
- Assume variable names without checking

### Version Management
**DO**:
- Check GitHub releases for latest stable version
- Use `latest` tag when appropriate unless specific version needed

**DON'T**:
- Use arbitrary version numbers without verification

### Configuration Research
**DO**:
- Check project official docs, GitHub issues, source code
- Look for existing configuration examples in the project

**DON'T**:
- Guess environment variable names

### Network Configuration
**DO**:
- Use service names (e.g., `http://ollama:11434`) when services share a network

**DON'T**:
- Use `host.docker.internal` unnecessarily when shared network allows direct connections

### Persistent Data Directory Conventions
**DO**:
- Use standard directory names: `./data`, `./config`, `./logs`, `./nginx`
- Use generic variable names like `HOST_DATA_DIR` unless multiple services need distinction
- Allow configuration via `.env` file
- Create directories as needed, not preemptively

**DON'T**:
- Default to home directory (`~/.service`) unless project requires it

### Environment File Best Practices
**DO**:
- Comment out variables that have same default in compose file
- Always provide default fallback values in `docker-compose.yml` using `${VAR:-default}` syntax
- Add alternative configurations as commented examples when useful

### Port Management
**DO**:
- Assign unique external port numbers to avoid conflicts between stacks
- Default bind to `127.0.0.1` to prevent external access
- Use environment variables for port configuration: `${BIND_PORT:-DEFAULT}`
- Document port assignments to prevent overlaps in `PORTS.md`. Update the file when changing stack configuration.

**DON'T**:
- Use overlapping port ranges between stacks

## Research Checklist

Before creating a stack:

- **Version Check**: Find latest stable release on GitHub
- **Documentation Review**: Read official docs for environment variables
- **Model Format**: Verify correct model naming convention
- **Network Requirements**: Check if external networks are needed
- **Data Patterns**: Follow existing stack data directory conventions and adapt the app to them

## Validation Steps

1. **Config Test**: Run `docker-compose config` to validate syntax
2. **Variable Check**: Ensure all environment variables have proper defaults (unless they should be set by the user manually)
3. **Network Test**: Verify external networks are documented (`_docs/*.md` and optional `README.md` in the stack directory)
4. **Documentation**: Only create README.md if root README doesn't cover it

### Security Patterns
**DO**:
- Use `user: "${UID:-1000}:${GID:-1000}"` for security when image supports that
- Use LinuxServer.io convention (`PUID`/`PGID`) when applicable
- Mount Docker socket carefully and only when necessary: `/var/run/docker.sock:/var/run/docker.sock`
- Use read-only mounts when no writes expected: `/etc/localtime:/etc/localtime:ro`

**DON'T**:
- Run containers as root unless absolutely necessary (for containers that don't document using UID/GID)

### Image Tag Patterns
**DO**:
- Pin versions for critical services (databases, core infrastructure)
- Use `${IMAGE_TAG:-version}` for configurability

### Volume Mount Conventions
**DO**:
- Use parameterized local directories: `${HOST_DIR:-./default}:/container/path`
- Follow standard directory names: `./data`, `./config`, `./logs`
- Include timezone synchronization when service can use it: `/etc/localtime:/etc/localtime:ro`

### Multi-Service Stack Patterns
**DO**:
- Use custom networks for multi-service stacks when it adds benefits
- Use `depends_on` for service dependencies
- Use descriptive container names: `service-component` format
- Use service-to-service communication over external networking

**DON'T** Add custom networks everywhere

### Health Checks
**DO**:
- Include health checks for critical services (databases, web apps)
- Comment them out by default to avoid startup delays

### Config File Management
**DO**:
- Provide `.dist` versions for template configs requiring user customization
- Add user-modified versions to local `.gitignore` (in same directory, not root)
- Place Nginx configs in `nginx/` subdirectory
- If service exposes HTTP port, provide Nginx config file based on existing stack principles
- Place application configs in `config/` subdirectory

## Docker Compose Best Practices

### Schema and Structure
**DO**:
- Reference environment variables via `env_file: .env`, use `environment:` only if needed or if values are really static
- Use `restart: unless-stopped` for most services
- Add comments with links to official images/documentation

**DON'T**:
- Use schema version (deprecated)

### Logging Configuration (Required)
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "${LOG_MAX_SIZE:-5m}"
    max-file: "${LOG_MAX_FILE:-5}"
```

### Volume Best Practices
**DO**:
- Use parameterized local directories: `${HOST_DIR:-./default}:/container/path`
- Use named volumes for persistent data
- Use bind mounts for configuration files
- Include timezone synchronization when service can use it: `/etc/localtime:/etc/localtime:ro`

## Step-by-Step Creation Checklist

1. **Create directory** at root level
2. **Add `docker-compose.yml`** with proper structure and defaults
3. **Create `.env.dist`** with all variables and comments
4. **Add `README.md`** only if root README doesn't cover special requirements
5. **Add config directories** as needed with `.dist` templates
6. **Update root `README.md`** table with new stack entry
7. **Commit safe files** (exclude `.env`, include `.env.dist` and templates)

## Version Control Rules

**DO**:
- Commit `.env.dist` and config templates

**DON'T**:
- Commit `.env` or files containing secrets
