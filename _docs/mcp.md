# MCP Client Configuration

Several stacks in this repository expose [MCP](https://modelcontextprotocol.io) (Model Context Protocol) servers; the current list is below. This page explains how to connect an MCP client — Claude Code, Codex, OpenCode, or Hermes — to any MCP server over either transport, including authenticated streamable HTTP endpoints. All examples use placeholder URLs and tokens written directly into the configuration files, so they can be applied to any MCP server.

## MCP Servers in This Repository

| Stack | Provides | Client authentication |
|---|---|---|
| [mcp-forgejo](../mcp-forgejo/README.md) | Forgejo repositories, issues, and pull requests | Per-request `Authorization: token <token>` or `Bearer <token>` |
| [mcp-obscura](../mcp-obscura/README.md) | Headless browser automation | None |
| [mcp-basic-memory](../mcp-basic-memory/README.md) | Markdown knowledge base queries | None; protected at the network layer |
| [mcp-mastodon](../mcp-mastodon/README.md) | Mastodon/GoToSocial accounts, timelines, and statuses | Custom header `X-Mastodon-Access-Token` |
| [mcp-miniflux](../mcp-miniflux/README.md) | Miniflux RSS feeds and entries | `Authorization: Bearer <token>` (`MCP_AUTH_TOKEN`) |
| [hindsight](../hindsight/README.md) | Long-term memory for AI agents | `Authorization: Bearer <token>` (`HINDSIGHT_API_KEY`) |

Endpoint URLs and ports live in each stack README and in [PORTS.md](../PORTS.md), so they are documented in one place only. Hindsight serves one MCP endpoint per memory bank with the bank id in the URL path.

## Transports

- **stdio** — the client launches the server as a local subprocess and talks over stdin/stdout. Configuration names a `command` with `args` and an environment for the child process.
- **Streamable HTTP** — the client connects to a URL over HTTP and sends authentication headers on each request. All MCP servers in this repository use this transport.

| Agent | stdio | Streamable HTTP | Notes |
|---|---|---|---|
| Claude Code | yes | yes | `"sse"` entries are deprecated |
| Codex | yes | yes | streamable HTTP is the only remote transport |
| OpenCode v1 | yes (`local`) | yes (`remote`) | |
| OpenCode v2 | yes | yes | config layout differs from v1; see below |
| Hermes | yes | yes | |

## Choosing a URL

- Agent running on the Docker host: use the localhost-published endpoint, `http://127.0.0.1:<published-port>/<endpoint-path>`. Published ports are in [PORTS.md](../PORTS.md); endpoint paths are in each stack README.
- Agent running as a container on the shared `ai-tools` network: use the container name, `http://<compose-service>:<container-port>/<endpoint-path>`. See the [`ai-tools` network guide](./ai_tools_network.md).
- Agent running elsewhere on the LAN: enable the stack's Traefik variant and use `https://<stack-host>/<endpoint-path>`. See the [Traefik usage guide](./traefik.md).

## Authentication

Streamable HTTP servers authenticate requests with HTTP headers. The two common styles are a Bearer token:

```text
Authorization: Bearer <token>
```

and a custom header:

```text
X-Example-Token: <token>
```

Which style a stack expects is listed in the table above. Every example below writes the token literally into the client configuration. Each agent also offers environment-variable indirection (Claude Code `${VAR}` in header values, Codex `bearer_token_env_var`, OpenCode `{env:NAME}`); it is deliberately not used here.

## Claude Code

Project-scoped servers live in `.mcp.json` at the project root; user- and local-scoped servers live in `~/.claude.json` (top-level `mcpServers` for user scope). Claude Code does not read `~/.claude/mcp.json`.

```json
{
  "mcpServers": {
    "example-stdio": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@scope/example-mcp"],
      "env": {
        "EXAMPLE_API_KEY": "replace-with-api-key"
      }
    },
    "example-http": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "headers": {
        "Authorization": "Bearer replace-with-token"
      }
    }
  }
}
```

To authenticate with a custom header instead, replace the `headers` content:

```json
"headers": {
  "X-Example-Token": "replace-with-token"
}
```

- An entry with `url` but no `type` is treated as stdio and fails to connect; always set `"type": "http"`.
- `"streamable-http"` is accepted as an alias for `"http"`.
- `"sse"` is deprecated; prefer `"http"`.

The same servers can be added with the CLI:

```shell
claude mcp add --transport http example-http https://mcp.example.com/mcp \
  --header "Authorization: Bearer replace-with-token"
```

`--scope` selects `local`, `user`, or `project`; stdio servers need the `--` separator before the command; `claude mcp add-json` accepts the JSON entry directly.

## Codex

Codex reads `~/.codex/config.toml`, or `.codex/config.toml` in a trusted project. Each server is a `[mcp_servers.<name>]` table:

```toml
[mcp_servers.example-stdio]
command = "npx"
args = ["-y", "@scope/example-mcp"]
env = { "EXAMPLE_API_KEY" = "replace-with-api-key" }

[mcp_servers.example-http]
url = "https://mcp.example.com/mcp"
http_headers = { "Authorization" = "Bearer replace-with-token" }
```

`http_headers` holds static header values, so a custom header is another entry in the same map:

```toml
http_headers = { "X-Example-Token" = "replace-with-token" }
```

`bearer_token_env_var` also exists but reads the token from the environment. Optional per-server keys include `startup_timeout_sec`, `tool_timeout_sec`, and `enabled`.

## OpenCode v1

OpenCode v1 reads `opencode.json` (or `.jsonc`) with servers under the `mcp` key. Local servers are `"type": "local"` and take a command array; remote servers are `"type": "remote"` and take `url` plus `headers`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "example-stdio": {
      "type": "local",
      "command": ["npx", "-y", "@scope/example-mcp"],
      "environment": {
        "EXAMPLE_API_KEY": "replace-with-api-key"
      }
    },
    "example-http": {
      "type": "remote",
      "url": "https://mcp.example.com/mcp",
      "headers": {
        "Authorization": "Bearer replace-with-token"
      },
      "oauth": false
    }
  }
}
```

Set `"oauth": false` on servers that use static tokens so OpenCode does not start an OAuth flow. A custom header is another entry in `headers`. `enabled` toggles a server, and `timeout` overrides the default 5000 ms tool timeout.

## OpenCode v2

OpenCode v2 changes the layout: servers move under `mcp.servers`, and `disabled` (default `false`) replaces v1's `enabled`. Local servers are defined by `command`, remote servers by `url`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "example-stdio": {
        "command": ["npx", "-y", "@scope/example-mcp"],
        "environment": {
          "EXAMPLE_API_KEY": "replace-with-api-key"
        }
      },
      "example-http": {
        "url": "https://mcp.example.com/mcp",
        "headers": {
          "Authorization": "Bearer replace-with-token"
        },
        "oauth": false
      }
    }
  }
}
```

`command` accepts a string or an array, `headers` take literal values, and `oauth` is either `false` or an object with snake_case fields (`client_id`, `client_secret`, `scope`). OpenCode's `{env:NAME}` interpolation also exists but is not used in these examples.

## Hermes

Hermes reads `~/.hermes/config.yaml` and launches or connects to everything under `mcp_servers:`:

```yaml
mcp_servers:
  example-stdio:
    command: "npx"
    args: ["-y", "@scope/example-mcp"]
    env:
      EXAMPLE_API_KEY: "replace-with-api-key"
  example-http:
    url: "https://mcp.example.com/mcp"
    headers:
      Authorization: "Bearer replace-with-token"
```

A custom header replaces the `headers` content:

```yaml
    headers:
      X-Example-Token: "replace-with-token"
```

Per-server keys include `enabled`, `timeout`, `connect_timeout`, and `tools` with `include`/`exclude` lists for tool filtering. After editing the config, run `/reload-mcp` in a Hermes session or restart Hermes.

In this repository's [Hermes stack](../hermes/README.md), the config file lives at `${HOST_DATA_DIR:-./data}/config.yaml` (mounted at `/opt/data/config.yaml` in the container) and can be edited with `docker compose exec hermes hermes config edit`. The stack joins the `ai-tools` network, so Hermes reaches the repository's MCP stacks by container name.

## References

- [Claude Code MCP](https://code.claude.com/docs/en/mcp)
- [Codex MCP](https://developers.openai.com/codex/mcp)
- [OpenCode v1 MCP servers](https://opencode.ai/docs/mcp-servers/)
- [OpenCode v2 MCP servers](https://opencode.ai/v2/docs/mcp-servers/)
- [Hermes MCP](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/mcp.md)
- [MCP transports](https://modelcontextprotocol.io/docs/concepts/transports)
