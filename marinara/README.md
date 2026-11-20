# Marinara Engine

[Marinara Engine](https://github.com/Pasta-Devs/Marinara-Engine) is a
self-hosted AI chat and roleplay frontend. It talks to OpenAI-compatible
providers such as the repository's [llama-swap](../llama-swap/README.md)
stack, stores all state as plain JSON files under `./data`, and needs no
external database.

The stack defaults to the full image (`IMAGE_TAG=latest`), chosen for
the application features it unlocks - built-in Memory Recall in
particular - with the bundled local model kept dormant and every model
role served by external providers (see
[Image variants](#image-variants)).

## Prerequisites

This stack requires the external `ai-tools` Docker network. Please follow
the [ai-tools](../_docs/ai_tools_network.md) configuration guide before
starting the service. Publishing through Traefik (the default compose
variant) additionally requires the shared `traefik` network - see the
[Traefik network setup](../_docs/traefik_network.md).

The stack defaults to the `traefik` compose variant and is served through
the Traefik instance under `TRAEFIK_HOST`. The `default` variant is the
localhost opt-out, binding the web UI to `127.0.0.1:7860`; with no
credentials configured, the app accepts localhost connections only.

## Setup

1. Copy `.env.dist` to `.env`.
2. For the default Traefik variant, set in `.env` (see
   [Authentication and Traefik exposure](#authentication-and-traefik-exposure)):
   `TRAEFIK_HOST`, then the `BASIC_AUTH_USER`/`BASIC_AUTH_PASS`/
   `ADMIN_SECRET` trio, then `TRUSTED_HOSTS` and `CSRF_TRUSTED_ORIGINS`.
3. Start the stack with `docker compose up -d`.
4. Open `https://<TRAEFIK_HOST>` (or `http://127.0.0.1:7860` on the
   localhost `default` variant) and add a connection as described below.

Until the settings from step 2 exist, the Traefik variant reports
`unhealthy` on purpose: the container healthcheck validates them and
names the missing variables (never their values) in its health log, so
`docker compose up -d --wait` fails instead of silently leaving a
locked, unreachable deployment behind. The standalone `default` variant
performs no such validation.

To run without Traefik instead, set `COMPOSE_VARIANT=default` in `.env`
and keep the port localhost-bound while no password is set.

The container starts as root, repairs the ownership of the bind-mounted
data directory, and then drops privileges, so no manual `chown` of
`./data` is required. On first start the app generates an
`.encryption-key` file inside the data directory (see
[Data and backups](#data-and-backups)).

## Image variants

The same image repository publishes a full and a lite line:

| Tag(s)                                | Contents                                                                                                          |
|---------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| `latest` (default), pinned `X.Y.Z` (e.g. `2.5.2`) | Full image, recommended stable. Includes the local Gemma model, local embeddings, Memory Recall, and local Whisper. |
| `lite`, pinned `X.Y.Z-lite`  | Same application without the bundled local models. Works with external providers, but see [Choosing between lite and full](#choosing-between-lite-and-full). |

The moving `latest`/`lite` tags always point at the current stable
release. Never pin anything in the `2.0.9` - `2.3.3` range: those
releases were withdrawn upstream for a security issue and their image
artifacts were removed.

### What each image line includes

Lite supports everything through external services: text generation
via OpenAI-compatible providers such as the repository's llama-swap
stack, and external embeddings from a connection, which are enough for
[lorebook semantic search](#embeddings-and-semantic-search). The
upstream "left out" list for lite is short: the built-in local chat
model, the local embedding model, Memory Recall, local Whisper voice
input, and the avatar mood reader. Memory Recall stays off on lite
even when an external embedding service is configured - it depends on
the local embedding model, not on any embedding-capable connection.
Advanced Memory Recall and Character recollections are not affected by
the image line: upstream does not list them among the lite
limitations.

Full supports the same external services and additionally carries the
optional built-in components: the bundled local Gemma chat model
(opt-in per chat through **Model for this chat** - nothing forces it
as the chat model), the local embedding model that Memory Recall
requires, and local Whisper voice input. See
[Recommended setup: Full with external inference](#recommended-setup-full-with-external-inference)
for the recommended way of running Full with every model role delegated
to llama-swap.

### Choosing between lite and full

`lite` is the choice when minimizing image size and native dependencies
matters most. The trade-off: it hard-disables built-in Memory Recall -
the section does not exist on lite, and no external embedding source
brings it back (upstream removes it together with the local embedding
model, even though on the full image Memory Recall happily runs on
connection embeddings). Full preserves the roleplay memory features
while all LLM and embedding inference can still be handled externally
(see
[Recommended setup: Full with external inference](#recommended-setup-full-with-external-inference)),
which is why it is the default here. The optional Long-Term Memory
package (below) is not a feature-equivalent replacement for the
built-in memory features.

### The optional Long-Term Memory package

Long-Term Memory is a separately installed agent package (from Agent
Organizer) and is distinct from both built-in Memory Recall and
Advanced Memory Recall: it extracts lasting memories from chat
summaries, character records and lorebooks into a package-owned,
durable vault inside the data directory and recalls relevant context
before the main reply.

It supports external embedding sources: recall embeds through the
package's connection, with the built-in local model only as a fallback
- and that fallback does not exist on lite, so there the package needs
an embedding model on a connection. Beyond that, upstream documents no
lite-specific restriction (engine compatibility 2.3.5 through before
4.0.0). It is not a feature-equivalent replacement for the built-in
features: in chats where it is on it replaces the built-in per-chat
recall entirely (v2.5.2 behavior) and it does not manage the live
history window the way Advanced Memory Recall does. Its vault, drafts
and settings are exported through the Memory Settings backup controls
and survive uninstall.

The default `IMAGE_TAG=latest` tracks the current stable release of the
full line. Switching between the lines is a one-line change in `.env`:

```shell
# full image, rolling stable (default) - enables Memory Recall
IMAGE_TAG=latest
# lite: smaller image, hard-disables built-in Memory Recall
#IMAGE_TAG=lite
# pinned alternatives
#IMAGE_TAG=2.5.2
#IMAGE_TAG=2.5.2-lite
```

The `staging` tag tracks unstable builds and must not share a data
directory with a stable deployment; point `HOST_DATA_DIR` at a separate
directory when testing staging.

## Recommended setup: Full with external inference

On a server with an AMD GPU and an existing llama-swap deployment, run
the Full image and delegate every model role to llama-swap. The GPU
belongs to llama-swap: this stack deliberately passes no GPU devices
(`/dev/dri`, `/dev/kfd`, or anything else) to the Marinara container -
do not add them. Full is selected for its additional application
features, especially Advanced Memory - not for its built-in inference
runtime. The bundled runtime and the local Gemma model do not need to
be installed, downloaded, or started: Advanced Memory works entirely on
external providers.

- **Chat / roleplay**: a local LLM through the llama-swap connection
  (see [Connecting to llama-swap](#connecting-to-llama-swap)).
- **Agent / helper models**: smaller llama-swap models, selected in
  Marinara for the agents and helper jobs doing background work.
- **Embeddings**: an embedding model served by llama-swap, selected
  under **Connections → Defaults → Embeddings** (see
  [Embeddings and semantic search](#embeddings-and-semantic-search));
  llama-swap can serve embedding models on CPU without any change to
  its model loading configuration.
- **Decision model**: optional - point the **Decision** row under
  **Connections → Jobs → Behind the scenes** at a small llama-swap
  model, or leave it on **None** (the default).
- **Memory**: with the Full image, built-in Memory Recall and Advanced
  Memory Recall are available and work over the configured external
  embedding source.
- **Built-in Marinara model**: do not download or enable it (below).

Keeping the built-in inference inactive: never download the Local Model
(the Gemma card in the Connections panel) and never use **Use local
model for all tracker agents**. The card's two switches - **Use for
tracker agents (roleplay)** and **Use for game scene analysis** - decide
whether Marinara keeps the local runtime running, and they appear only
after a model has been downloaded, so with no model downloaded the
runtime never starts on its own. (If a model was ever downloaded, turn
both switches off - **Use for game scene analysis** ships enabled.)
Installing the runtime is additionally a protected action on Docker
installs - it needs an `ADMIN_SECRET` entry or
`SIDECAR_RUNTIME_INSTALL_ENABLED=true` - so the built-in model stays
dormant unless deliberately enabled. Point the background jobs at
external providers instead: pick llama-swap models for agents and
helpers in the Defaults section of the Connections panel, and never
select **Local Model (sidecar)** in any model or embedding dropdown.

## Connecting to llama-swap

Add an OpenAI-compatible connection in the Marinara UI with the base URL

```text
http://llama-swap:8080/v1
```

reachable over the shared `ai-tools` network. Model IDs currently
configured in the repository's llama-swap stack
(`llama-swap/config/config.yaml.dist`):

```text
gemma-4-e2b
gemma-4-e4b
gemma-4-e4b-noreason
gemma-4-26b
gemma-4-31b
qwen-3-6-27b
qwen-3-6-35b
openwebui-title-generator-270m
```

`PROVIDER_LOCAL_URLS_ENABLED=true` (set in `.env.dist`; disabled upstream
by default) is required for Marinara to accept this private base URL.
llama-swap auth is disabled by default, so any placeholder API key (for
example `none`) works; if it runs with its optional `API_KEY` enabled,
use the same key for the Marinara connection.

Embedding models are configured separately on a connection - the
shipped llama-swap configuration includes none. See
[Embeddings and semantic search](#embeddings-and-semantic-search).

## Embeddings and semantic search

Embeddings power lorebook semantic search and, on the full image,
Memory Recall. They are configured per connection (see the upstream
[semantic search guide](https://github.com/Pasta-Devs/Marinara-Engine/blob/main/docs/lorebooks/semantic-search.md)):

1. Open a connection's model editor and find its **Semantic search
   (embeddings)** section.
2. Set **Embedding Model** to a model ID the service serves. The
   repository's llama-swap configuration ships no embedding model, so
   for that stack this is `<your-embedding-model-id>`: add such a model
   to `llama-swap/config/config.yaml.dist` yourself first. Alternatively
   configure a separate external embedding provider.
3. Optionally override where embedding requests go via **Embedding
   endpoint URL**, or borrow another account with **Embedding
   provider**. **Test embedding** verifies the setup before you
   vectorize anything.
4. To make one source the default for every connection that sets none,
   choose it under **Connections → Defaults → Embeddings**; a
   connection's own setting still wins, and the built-in local fallback
   entry exists only on the full image.

Semantic-search embeddings and Memory Recall availability are separate
things: lorebook semantic search works on the lite image with
connection embeddings, while Memory Recall requires the full image's
local embedding model and stays off on lite regardless of the
embedding source.

Stored vectors belong to the embedding model that produced them. After
switching embedding models, re-vectorize the affected lorebooks and
memories (**Re-vectorize all**) so every vector matches again:
mismatching entries are skipped in semantic matching without an error,
and Marinara refuses a partial re-vectorize when the vector dimensions
change.

Serving an embedding model through llama-swap needs nothing beyond
listing the model in its config; how llama-swap loads, keeps resident,
and swaps models is its own concern (see the
[llama-swap README](../llama-swap/README.md)). For slow embedding
backends, raise `EMBEDDING_TIMEOUT_MS` (default 300000 ms) in `.env`.

## Image generation with MiniMax-H3-Image

Image generation runs against the native MiniMax API, without a proxy
stack (the repository's minimax-openai-image-proxy targets the older
`image-01` model): MiniMax serves `MiniMax-H3-Image` behind an
OpenAI-compatible images endpoint at `https://api.minimax.io/v1`
([image generation guide](https://platform.minimax.io/docs/guides/image-generation)).

1. Create an API key in the [MiniMax platform](https://platform.minimax.io)
   under API Keys. The key belongs in Marinara's connection settings
   only - never in compose files or `.env`.
2. In Marinara, open **Connections**, click **Add**, and create an
   account under the **Images & video** section as a generic
   **OpenAI-compatible** service (the workflow is documented in the
   upstream [image provider guide](https://github.com/Pasta-Devs/Marinara-Engine/blob/main/docs/media/image-providers.md)).
3. Set the account address to `https://api.minimax.io/v1` and paste the
   API key.
4. Add an image model to the account and type the model ID
   `MiniMax-H3-Image` (`MiniMax-H3-Image-Highspeed` is a faster variant
   with the same parameters and limits).
5. Open the image model and click **Test image** - it makes a real
   picture and can use credit.
6. Set the **Images** job under **Defaults** at the top of the
   Connections panel to make it the app-wide picture model. The
   [Illustrator agent](https://github.com/Pasta-Devs/Marinara-Engine/blob/main/docs/media/illustrator-agent.md)
   uses the same default, or can be given its own image model on its
   **Open Setup** screen.

### Reference images are not supported through this connection

MiniMax-H3-Image itself accepts 1-16 reference images for image
editing, but Marinara's OpenAI-compatible image handler only routes
reference-image editing to GPT Image models (`gpt-image-1`, `1.5`,
`2`); every other model gets a plain text-to-image
`/images/generations` request and any reference images are dropped.
Leaving **Send Avatar References** on for the Illustrator therefore
does not make avatar references work with MiniMax: standard
text-to-image generation works, sending NPC/character avatar references
to MiniMax-H3-Image does not. This is a Marinara integration
limitation, not a MiniMax one.

## Data and backups

All state is file-native JSON under `DATA_DIR` (`/app/data`,
bind-mounted from `./data` by default); there is no external database.
In-app backups are written to `backups/` inside the same directory, so
copy them elsewhere for real protection. Back up the whole data
directory together with `.env`; it includes the auto-generated
`.encryption-key`.

Version changes (updates and switches between the lite and full images)
can apply one-way storage-format migrations: once a newer release has
opened the data directory, older releases may no longer be able to read
it (the v2.5.2 migration is one-way, and v2.5.1 and older cannot open
the data afterwards). Always back up `./data` before changing versions.

`MARINARA_SKIP_DATA_CHOWN=true` is available in `.env` as an escape
hatch when the startup ownership repair must be skipped.

## Authentication and Traefik exposure

Since v2.4.0 Marinara requires authentication for traffic arriving
through a reverse proxy (`REQUIRE_AUTH_FOR_DOCKER_PROXY=true` upstream
default), and newer releases additionally classify tunneled and
container-name traffic as remote. The Traefik variant therefore stays
locked until the credentials below are set; without them the app
accepts localhost connections only.

Set all three in `.env` (they reach the container via `env_file`):

```shell
BASIC_AUTH_USER=replace-with-username
BASIC_AUTH_PASS=replace-with-generated-secret
ADMIN_SECRET=replace-with-generated-secret
```

Generate secrets with `openssl rand -hex 32`. On Docker installs
`ADMIN_SECRET` is required for privileged actions (backups, data
clearing, updates, runtime install). Since v2.5.2 browsers get an
in-app sign-in page instead of the native Basic Auth dialog; Basic
Auth headers keep working for scripts and API clients.

For the default Traefik variant, configure `TRAEFIK_HOST` (plus the other
`TRAEFIK_*` variables when deviating from the defaults). Reverse-proxy
access additionally needs:

```shell
TRUSTED_HOSTS=marinara.example.com
CSRF_TRUSTED_ORIGINS=https://marinara.example.com
#CORS_ORIGINS=https://marinara.example.com
```

`TRAEFIK_ACCESS_POLICY` (default `default-access@file`) only selects a
middleware chain that is already configured in the shared Traefik
stack's dynamic configuration; this stack does not define one, and what
`default-access@file` does depends on the live Traefik config (template:
[`traefik/config/dynamic/default-access.yml.dist`](../traefik/config/dynamic/default-access.yml.dist)),
so do not assume it is inherently private. Keep it as an allow list for
LAN/VPN clients in front of the app-level authentication, or select an
existing authenticated policy such as `public-auth-access@file`
(Authelia SSO) when the deployment provides one; Marinara's own
authentication requirements apply either way. See the
[access policy notes](../_docs/traefik.md#access-policy) in the common
[Traefik usage guide](../_docs/traefik.md) and the
[network setup](../_docs/traefik_network.md).

## Updating

Back up `./data` first (see
[Data and backups](#data-and-backups)): releases can apply one-way
storage-format migrations, and a release that already migrated the
data cannot be rolled back.

```shell
docker compose pull
docker compose up -d
```

The same procedure applies after switching `IMAGE_TAG` between the lite
and full images.

## References

- [Github](https://github.com/Pasta-Devs/Marinara-Engine)
- [Docker installation guide](https://github.com/Pasta-Devs/Marinara-Engine/blob/main/docs/installation/containers.md)
- [Memory documentation](https://github.com/Pasta-Devs/Marinara-Engine/blob/main/docs/agents/memory.md)
- [Lorebook semantic search guide](https://github.com/Pasta-Devs/Marinara-Engine/blob/main/docs/lorebooks/semantic-search.md)
- [Image provider setup](https://github.com/Pasta-Devs/Marinara-Engine/blob/main/docs/media/image-providers.md)
- [MiniMax image generation API guide](https://platform.minimax.io/docs/guides/image-generation)
