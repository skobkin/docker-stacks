# Llama Swap

[llama-swap](https://github.com/mostlygeek/llama-swap) is a local model router
that exposes OpenAI-compatible APIs and can hot-swap between model backends on
demand.

## Prerequisites

This service requires the external `ai-tools` Docker network. Please follow the
[ai-tools](../_docs/ai_tools_network.md) configuration guide before starting the
service.

## Default Behavior

This stack defaults to the upstream `ghcr.io/mostlygeek/llama-swap:vulkan`
image so built-in `llama.cpp` model serving can use AMD Vulkan devices exposed
from the host.

Open WebUI can reach the OpenAI-compatible endpoint at
`http://llama-swap:8080/v1` over the shared `ai-tools` network.

## Setup

1. Copy `.env.dist` to `.env`.
2. Copy `config/config.yaml.dist` to `config/config.yaml`.
3. Place your GGUF files in `./models`.
4. Review the filenames and tuning values in `.env`.
5. Start the stack with `docker compose up -d`.

The config file is watched at runtime, so edits to `config/config.yaml` are
picked up without rebuilding the stack.

## Optional vLLM Template

`config/config.yaml.dist` also includes one commented ROCm `vLLM` example for
Gemma 4 E4B. It is only a template by default.

To make that example usable, you need to:

1. Provide Docker access from wherever `llama-swap` executes the command.
2. If `llama-swap` stays containerized, add Docker CLI and socket access
yourself; this stack does not enable that by default.
3. Set absolute host paths for the `VLLM_*_HOST_*` mount variables in `.env`.
4. Ensure the host has working ROCm device access for `/dev/dri` and `/dev/kfd`.

For general setup instructions, please refer to the [root README](../README.md).
