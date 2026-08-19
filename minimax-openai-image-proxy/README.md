# MiniMax OpenAI Image Proxy

[minimax-openai-image-proxy](https://git.skobk.in/skobkin/minimax-openai-image-proxy)
is a small stateless Go service that exposes an OpenAI-compatible
`/v1/images/generations` endpoint and translates requests to the
[MiniMax](https://api.minimax.chat/) `image-01` model.

Open WebUI's built-in `generate_image` tool can drive MiniMax by pointing it
at this service without any frontend changes.

## Prerequisites

This service requires the external `ai-tools` Docker network. Please follow
the [ai-tools](../_docs/ai_tools_network.md) configuration guide before
starting the service.

## Setup

1. Copy `.env.dist` to `.env`.
2. Set `MINIMAX_TOKEN` to a valid bearer from the MiniMax Token Plan page.
3. Start the stack with `docker compose up -d`.

Open WebUI can reach the proxy over the shared `ai-tools` network at
`http://minimax-openai-image-proxy:8080/v1`. Set
`OPENAI_API_BASE_URL=http://minimax-openai-image-proxy:8080/v1` and any
non-empty `OPENAI_API_KEY` in Open WebUI's environment; the proxy does not
verify the key but Open WebUI requires the variable to be set to enable
its OpenAI-compatible backend.

## Optional Traefik exposure

Set `COMPOSE_VARIANT=traefik` in `.env` to attach the service to the
external Traefik network and expose it under the configured `TRAEFIK_HOST`.
The image-proxy backend is unauthenticated; use the
`default-access@file` access policy (the default) unless you intentionally
want public exposure, in which case switch to `public-access@file`.

For general setup instructions, please refer to the [root README](../README.md).
