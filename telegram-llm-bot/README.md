# Telegram LLM bot

[Telegram LLM bot](https://git.skobk.in/skobkin/telegram-ollama-reply-bot) is a Telegram bot which uses an OpenAI-compatible LLM backend to participate in discussions, summarize text, describe images, use tools, and manage reminders.

## Prerequisites

This service requires the `ai-tools` Docker network. Please follow the [network configuration guide](../_docs/ai_tools_network.md) before starting the service.

When using the repo-local llama-swap stack, set `LLM_BACKEND_OPENAI_COMPAT_BASE_URL=http://llama-swap:8080/v1`.
When using the repo-local Ollama stack directly, set `LLM_BACKEND_OPENAI_COMPAT_BASE_URL=http://ollama:11434/v1`.
The bot stores admin configuration and reminders in SQLite under `HOST_DATA_DIR` (`./data` by default).
Set `BOT_ADMIN_IDS` before using admin DM commands; leaving it empty disables admin controls.

For general setup instructions, please refer to the [root README](../README.md).
