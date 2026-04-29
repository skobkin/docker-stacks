# Ollama

[Ollama](https://ollama.com) is a toolkit for running large language models (LLMs) locally. It provides a simple way to download, run, and manage various LLM models.

## Prerequisites

This service requires the external `ai-tools` Docker network. Please follow the
[ai-tools](../_docs/ai_tools_network.md) configuration guide before starting the service.

If you want the container to join the external `proxy` network as well, enable
`COMPOSE_VARIANT=proxy` in `.env` and create the network as documented in
[proxy](../_docs/proxy_network.md).

## Notes

This stack now runs Ollama only. Open WebUI has been split into the sibling
[`open-webui`](../open-webui/README.md) stack and should connect to the `ollama`
container hostname over the shared `ai-tools` network.

For general setup instructions, please refer to the [root README](../README.md).
