# Telegram LLM bot

[Telegram LLM bot](https://git.skobk.in/skobkin/telegram-ollama-reply-bot) is a Telegram bot which uses an OpenAI-compatible LLM backend to participate in discussions, summarize text, describe images, use tools, and manage reminders.

## Prerequisites

By default, the container uses only the stack's default Docker network.

Set `COMPOSE_VARIANT=ai_tools` when the bot needs to reach repo-local LLM backends such as `llama-swap` or `ollama` on the shared `ai-tools` network. Create the network as documented in the [ai-tools](../_docs/ai_tools_network.md) guide.

Set `COMPOSE_VARIANT=proxy` when the bot needs the external `proxy` network. Create the network as documented in the [proxy](../_docs/proxy_network.md) guide.

Set `COMPOSE_VARIANT=ai_tools_proxy` when both external networks are needed.

When using the repo-local llama-swap stack, set `LLM_BACKEND_OPENAI_COMPAT_BASE_URL=http://llama-swap:8080/v1`.
When using the repo-local Ollama stack directly, set `LLM_BACKEND_OPENAI_COMPAT_BASE_URL=http://ollama:11434/v1`.
The bot stores admin configuration and reminders in SQLite under `HOST_DATA_DIR` (`./data` by default).
Set `BOT_ADMIN_IDS` before using admin DM commands; leaving it empty disables admin controls.

For general setup instructions, please refer to the [root README](../README.md).
