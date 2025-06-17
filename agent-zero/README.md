# Agent Zero Stack

This stack runs [Agent Zero](https://github.com/frdel/agent-zero), a general-purpose personal AI agent framework.

## Additional Requirements

- **ai-tools network:** This stack requires the external Docker network `ai-tools` to be created in advance. You can create it with:
  ```sh
  docker network create ai-tools
  ```
- **Persistent storage:** The `data/` directory is mounted for persistent storage. Make sure it is writable by Docker.
- **Environment variables:** Copy `.env.dist` to `.env` and adjust as needed before starting the stack.
- **API keys and advanced configuration:** Set these in the web UI after first launch.

## Quick Start

1. Copy the environment template and edit as needed:
   ```sh
   cp .env.dist .env
   nano -w .env
   ```
2. Start the stack:
   ```sh
   docker-compose up -d
   ```
3. Access the web UI at `http://127.0.0.1:50001` (or as configured).

- For more details, see the [root README](../README.md) and the [official documentation](https://github.com/frdel/agent-zero#readme). 