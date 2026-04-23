# Open WebUI

[Open WebUI](https://docs.openwebui.com) is a self-hosted web interface for local
and remote LLM backends.

## Prerequisites

This service requires the external `ai-tools` Docker network. Please follow the
[ai-tools](../_docs/ai_tools_network.md) configuration guide before starting the service.

If you want the container to join the external `proxy` network as well, enable
`COMPOSE_VARIANT=proxy` in `.env` and create the network as documented in
[proxy](../_docs/proxy_network.md).

## Notes

This stack expects a sibling Ollama deployment to be reachable as `ollama` on the
shared `ai-tools` network.

For general setup instructions, please refer to the [root README](../README.md).
