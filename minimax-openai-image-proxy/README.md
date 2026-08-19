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
2. Start the stack with `docker compose up -d`.

The API key is supplied by the caller (Open WebUI) at request time as
`Authorization: Bearer <key>` and is forwarded upstream unchanged on every
request. The service does not store the key.

For the Open WebUI side of the wiring, see the
[Open WebUI configuration](https://git.skobk.in/skobkin/minimax-openai-image-proxy#open-webui-configuration)
section in the upstream README.

## Optional Traefik exposure

Set `COMPOSE_VARIANT=traefik` in `.env` to attach the service to the
external Traefik network and expose it under the configured `TRAEFIK_HOST`.
The image-proxy backend is unauthenticated; use the
`default-access@file` access policy (the default) unless you intentionally
want public exposure, in which case switch to `public-access@file`.

For general setup instructions, please refer to the [root README](../README.md).
