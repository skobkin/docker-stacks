# Anubis

This stack runs [Anubis](https://anubis.techaro.lol/) as a shared AI-bot firewall. Anubis sits in front of any Traefik-proxied service and issues a proof-of-work challenge to suspicious clients before they reach the application. It is exposed as a Traefik [`forwardAuth`](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/forwardauth/) middleware called `anubis@file`, so any stack in this repository can opt into bot protection with a one-line `TRAEFIK_ACCESS_POLICY` change.

## How the integration works

The default flow is **in-site**: Anubis is not exposed on a public hostname of its own. The Traefik file-provider config in [`traefik/config/dynamic/anubis.yml.dist`](../traefik/config/dynamic/anubis.yml.dist) defines three objects:

- `anubis@file` — the `forwardAuth` middleware that calls Anubis on the shared `traefik` network at `http://anubis:8923/.within.website/x/cmd/anubis/api/check`.
- `anubis-static@file` — a low-priority catch-all router that matches `PathPrefix("/.within.website/")` on `websecure` and serves the Anubis challenge page and its static assets. The Anubis 401 response body is HTML that references same-origin assets under `/.within.website/` (CSS, JS for the PoW solver); this catch-all routes those requests to Anubis.
- `anubis@file` (service) — the upstream that both the forwardAuth middleware and the catch-all router talk to.

When a request hits a protected stack, Traefik runs the middlewares in the order they appear in the router's `middlewares:` list. The `forwardAuth` middleware proxies the request to Anubis, which inspects the policy file. If the policy says `ALLOW`, Traefik forwards the original request to the application. If the policy says `CHALLENGE`, Anubis's `api/check` endpoint behaviour depends on `PUBLIC_URL`. With `PUBLIC_URL` set, the endpoint returns HTTP 302 to `<PUBLIC_URL>/.within.website/?redir=...` and Traefik follows the redirect through the `anubis-static` catch-all, which serves the Anubis challenge page and its same-origin static assets. With `PUBLIC_URL` unset, the endpoint returns HTTP 401 with a 22-byte `Authorization required` body, and the user is stuck on a bare 401 with no path to the challenge page — this is the failure mode that the `PUBLIC_URL` env var exists to avoid. See the "Required env vars" section below.

The challenge HTML uses **relative URLs** for its form `action=` and asset references. The browser resolves them to the protected host the user is actually on (`forgejo.example.com`, `woodpecker.example.com`, etc.), so a single Anubis instance works for an arbitrary number of protected hosts without per-host config. Each protected host is its own origin from the cookie's perspective, which means the user solves the challenge once per host. This is by design: it keeps the cookie scoped to a single origin and avoids any cross-host trust surface.

Middleware order matters: ALL middlewares in the list run on every request. The existing `default-access@file` middleware in this repo is an `ipAllowList`; when it returns 403, Traefik short-circuits the request and Anubis never sees it. Anubis only ever sees requests that pass the `ipAllowList`. A request from a client in the allow list still goes through both Anubis and the application — there is no implicit "LAN clients skip the challenge" behaviour. The Anubis policy file is the only place to express that kind of exemption.

## Quick start

```shell
cp .env.dist .env
cp config/policy.yml.dist config/policy.yml
nano -w .env
docker compose up -d
```

The default `.env` requires `PUBLIC_URL` (and `COOKIE_DOMAIN` + `REDIRECT_DOMAINS` for multi-subdomain deployments). See the "Required env vars" section below for the full list and the consequences of leaving them unset. After `docker compose up -d`, Anubis is reachable on the shared `traefik` network as `anubis:8923` and on `127.0.0.1:8923` on the host for direct verification and debugging.

## Required env vars

The default in-site flow is not zero-config. Three Anubis container env vars are required to make the challenge work end-to-end; one more is required only for the `traefik_exposed` cross-origin variant. They are commented out in `.env.dist` so operators see them when editing the file, but they are not optional.

### Always required (in-site and cross-origin flows)

- `PUBLIC_URL` — the absolute origin the Anubis challenge page is served from. The Anubis container uses it to build the form `action=` URL and the success redirect target. In a single-host in-site deployment, this is the protected application's public origin. In a cross-origin deployment, this is the `anubis.example.com` origin. **Without `PUBLIC_URL` the api/check endpoint returns a 22-byte 401 body for every CHALLENGE and the browser is stuck on a bare 401.** Set it to the public origin (scheme + host, no trailing slash), for example `https://app.example.com` or `https://anubis.example.com`.
- `COOKIE_DOMAIN` — scopes the Anubis cookie across subdomains. A leading dot means the cookie is shared across all subdomains of the parent domain, for example `.example.com` covers `app.example.com` and `ci.example.com`. Required whenever Anubis protects more than one subdomain of the same registrable domain. Without it, the cookie is scoped to a single origin and the user has to re-solve the challenge on every other subdomain.
- `REDIRECT_DOMAINS` — security allowlist for the post-challenge redirect. After a successful challenge, Anubis only redirects the browser to a hostname that appears in this list. **Without it, Anubis behaves as an open redirector and can be abused for phishing.** Must list every public hostname Anubis protects, comma-separated, for example `app.example.com,ci.example.com,woodpecker.example.com`.

### Only required for the `traefik_exposed` cross-origin variant

- `TRAEFIK_HOST` — the public hostname Anubis itself is reachable on, for example `anubis.example.com`. Traefik issues a Let's Encrypt certificate for this host. Has no default in `compose.features.yml`; an unset value produces a Traefik router configuration error rather than a silently broken deployment.

These are documented in the `compose.features.yml` comments and the "Using the `traefik_exposed` variant" section below. The diagnostic context (why the 22-byte body happens, what `status_codes` actually controls) is in the basic-memory note `docker-stacks/anubis/anubis-v1-25-gist`.

## Enabling Anubis on a Traefik-proxied stack

Anubis is shared by every stack that uses the shared Traefik. The forwardAuth middleware that calls Anubis lives in the Traefik file-provider config and is only loaded when the operator copies the template into the live file-provider path:

1. Copy `traefik/config/dynamic/anubis.yml.dist` to `traefik/config/dynamic/anubis.yml` in the Traefik stack.
2. Make sure the Anubis stack is running on the same external `traefik` network as the Traefik stack.
3. In the target stack's `.env`, append `anubis@file` to the existing `TRAEFIK_ACCESS_POLICY`:

    ```dotenv
    # Default for private-by-default or public-by-default stacks.
    TRAEFIK_ACCESS_POLICY=default-access@file,anubis@file
    # Use this form for selectively-public stacks.
    # TRAEFIK_ACCESS_POLICY=public-access@file,anubis@file
    ```

4. Recreate the target stack:

    ```shell
    docker compose up -d
    ```

Stacks that already use `TRAEFIK_ACCESS_POLICY=public-auth-access@file` for Authelia can stack Anubis on top of it in the same comma-separated list:

```dotenv
TRAEFIK_ACCESS_POLICY=public-auth-access@file,anubis@file
```

The order in the list is the order the middlewares run, and all of them run on every request that reaches the router. `default-access@file` is an `ipAllowList`; when it returns 403, Anubis is never consulted. For requests that pass the allow list, Anubis runs next and either allows the request through or returns 401 with the challenge page.

## Excluding paths from Anubis (per stack)

The Anubis instance is shared, so path exemptions are expressed as policy-file rules that match the request's `host` against the protected stack's `TRAEFIK_HOST`. To exempt a path for a specific stack:

1. Find the stack's `TRAEFIK_HOST` from its `.env` (for example `forgejo.example.com`) and the path prefixes you want to exempt (for example `/api/webhooks` and `/.well-known/acme-challenge`).
2. Edit `config/policy.yml` and add a rule under `bots:`, **above** the `import: (data)/meta/default-config.yaml` line (place it under the `Per-stack exemptions` block) so the exemption takes precedence over the bundled default:

    ```yaml
    bots:
      - name: forgejo-webhooks-exempt
        expression:
          all:
            - host == "forgejo.example.com"
            - path.startsWith("/api/webhooks")
        action: ALLOW
      - import: (data)/meta/default-config.yaml
    ```

    To exempt multiple path prefixes for the same host, add more `path.startsWith(...)` clauses under the `all:` block, or split the rule into two `action: ALLOW` rules.

3. Reload the policy by recreating the Anubis container:

    ```shell
    docker compose up -d
    ```

4. Verify with `curl`:

    ```shell
    curl -I https://forgejo.example.com/api/webhooks
    ```

    The response should come from the application, not the Anubis challenge page. A request to a non-exempt path on the same host (`curl -I https://forgejo.example.com/`) should still return the Anubis challenge, which proves the exemption is scoped to the chosen paths only.

Common exemption patterns:

- Webhook receivers (`/api/webhooks`, `/hooks`) for GitHub, Stripe, or other third-party callbacks.
- ACME HTTP-01 challenges (`/.well-known/acme-challenge`) so Let's Encrypt validation does not get challenged.
- Health-check endpoints (`/healthz`, `/readyz`) for uptime monitors that do not solve challenges.
- Matrix federation endpoints (`/_matrix/federation/*`) for server-to-server traffic.

The Anubis policy expression language supports more conditions than `host ==` and `path.startsWith(...)`. See the [Anubis policy expressions documentation](https://anubis.techaro.lol/docs/admin/policy/expressions/) for the full reference, including `path_regex`, `user_agent_regex`, `remote_address`, and nested `any`/`all`/`not` blocks.

## Customization recommendations

- **Tune challenge difficulty.** The `DIFFICULTY` environment variable (4 by default) controls the proof-of-work cost. Increase it to slow down scrapers further; decrease it when legitimate users complain about slow challenges. See the [Anubis configuration documentation](https://anubis.techaro.lol/docs/).
- **Use the policy file for known-good bots.** The default `policy.yml.dist` already allows Kagi (search engine) and Gatus (status checker) by user-agent. To allow other known-good bots, uptime monitors, or RSS readers, add `user_agent_regex` matches with `action: ALLOW` near the top of the policy file. See the [Anubis policy documentation](https://anubis.techaro.lol/docs/admin/policy/).
- **The bundled default already denies the common DDoS source clouds.** The Anubis project's `_deny-pathological.yaml` (imported by the default-config in this dist) ships flat `remote_addresses` lists for Alibaba Cloud (AS45102) and Huawei Cloud (AS136907), so the deny fires without a Thoth subscription. The dist inherits this deny for free. If your backend or a trusted partner is hosted on one of those networks, add an explicit `ALLOW` rule above the default-config import for the affected ranges. To ban additional networks, use the `iplist2rule` workflow documented in the dist's header comment.
- **Allowlist trusted subnets.** Office, VPN, or monitoring subnets can be exempt from the challenge entirely by adding a `default-access@file` `ipAllowList` rule in the Anubis policy, or by combining Anubis with the existing `default-access@file` middleware (which already runs first when `TRAEFIK_ACCESS_POLICY=default-access@file,anubis@file`).
- **Pin the image tag for reproducibility.** The default `IMAGE_TAG=latest` rolls forward. Set a specific version in `.env` if you want reproducible builds.
- **Watch the Anubis logs.** Anubis logs challenge decisions to stdout. Increase the log retention by raising `LOG_MAX_FILE` or `LOG_MAX_SIZE` in `.env` when investigating.
- **Forward only the headers Anubis needs.** The included `anubis.yml.dist` forwards the same set of request headers as the Authelia forwardAuth middleware. Do not forward `Authorization`; Anubis does not consume it and leaking it can interfere with Traefik's normal auth handling.

## Verifying the setup

After the Anubis stack is up and the Traefik file-provider config is in place, check the wiring:

```shell
# Anubis forwardAuth endpoint is reachable from the host (returns 401).
curl -I http://127.0.0.1:8923/.within.website/x/cmd/anubis/api/check
# A protected stack returns the Anubis challenge instead of the application.
curl -I https://forgejo.example.com/
# A path exempt in policy.yml returns the application response.
curl -I https://forgejo.example.com/api/webhooks

# (traefik_exposed only) The Anubis challenge is served from the
# Anubis host's own origin rather than the protected host's origin.
curl -I https://anubis.example.com/
```

## Using the `traefik_exposed` variant (cross-origin / separate-host)

The default in-site flow is sufficient for the vast majority of deployments. The `traefik_exposed` compose variant exposes Anubis on a public hostname of its own (for example `anubis.example.com`), serves the challenge page from that origin, and redirects the browser back to the protected host on success. Use it when the protected applications sit on hostnames that are not suitable as the challenge origin (different registrable domain, no way to share cookies across origins, or you simply prefer a clean separation between the bot firewall and the apps it fronts).

### When to use it

- The protected applications span multiple registrable domains and you want a single Anubis cookie domain that scopes cleanly across them.
- You want the challenge served from a recognisable origin (`anubis.example.com`) rather than the application origin.
- You are willing to maintain a `REDIRECT_DOMAINS` allowlist of every public hostname Anubis protects.

If the protected applications all share a single registrable domain and the in-site cookie behaviour is fine, the default in-site flow is simpler and has a smaller security surface (no open-redirector allowlist to maintain).

### How the wiring works

The `traefik_exposed` service block in `compose.features.yml` adds the standard 7-label Traefik set to the Anubis container. The new host router (priority inherited from `Host(\`${TRAEFIK_HOST}\`)`) sits above the existing `anubis-static` catch-all (priority 1) in `traefik/config/dynamic/anubis.yml.dist`, so it wins on the new host for every path — including the `/.within.website/*` challenge assets. The catch-all continues to serve the in-site flow's static assets on the protected hosts. No change to the catch-all is required.

The Anubis image, the `anubis@file` forwardAuth middleware, the policy file, and the `anubis-static` catch-all are unchanged. The only thing the new variant adds is the host router and the `TRAEFIK_HOST` env var that wires up the cross-origin challenge.

### Variables you must set (cross-origin specific)

| Variable | Purpose | Example |
|---|---|---|
| `COMPOSE_VARIANT` | Selects the variant block in `compose.features.yml`. | `traefik_exposed` |
| `TRAEFIK_HOST` | Public hostname Anubis itself is reachable on. Has no default; Traefik fails to start the router if unset. | `anubis.example.com` |

`PUBLIC_URL`, `COOKIE_DOMAIN`, and `REDIRECT_DOMAINS` are also required — see the "Required env vars" section above. `TRAEFIK_NETWORK` and `TRAEFIK_ENTRYPOINTS` keep their existing defaults (`traefik` and `websecure`).

### `TRAEFIK_ACCESS_POLICY` for the new router

The `default-access@file` middleware in this repo is whatever is uncommented in `traefik/config/dynamic/default-access.yml.dist` — either a private `ipAllowList` (LAN ranges you trust) or a public `ipAllowList` (`0.0.0.0/0`, `::/0`). For a public Anubis challenge host you almost certainly want the **public** variant of `default-access` active in that file, or a different middleware (e.g. `public-access@file`). A private `default-access` on the Anubis router would 403 every browser before the challenge can run. This is the most common footgun when adopting `traefik_exposed` — check the active variant of `default-access` in your Traefik dynamic config before flipping the Anubis variant on.

### DNS and certificates

Create an A/AAAA record for `TRAEFIK_HOST` pointing at the Traefik instance, the same way you would for any other stack. Traefik's `websecure` entrypoint will issue a Let's Encrypt certificate for the new host using the entrypoint's default certresolver; no per-host TLS labels are needed (and adding them would conflict with the entrypoint default per the repo's Traefik conventions).

### Risks specific to this variant

- **Open redirector surface.** A misconfigured `REDIRECT_DOMAINS` (empty, or missing a host) makes the Anubis challenge a phishing redirector. The `REDIRECT_DOMAINS` line in `.env.dist` is intentionally commented to force operators to think about it.
- **Cookie scope.** A too-broad `COOKIE_DOMAIN` (for example `.com`) would share the Anubis cookie across unrelated properties you may own. Use the narrowest scope that covers every protected hostname.
- **`TRAEFIK_ACCESS_POLICY` footgun.** A private `default-access` on the Anubis router 403s every browser before the challenge can run. Check which variant of `default-access` is active in your Traefik dynamic config.
- **Reverse-proxy loops.** Do not add `anubis@file` (the forwardAuth middleware) to the Anubis host router's middleware list. Anubis would forwardAuth against itself. The `traefik_exposed` service block deliberately omits it.

Tracking issue: <https://git.skobk.in/skobkin/docker-stacks/issues/333>.

## References

- [Anubis project home](https://anubis.techaro.lol/)
- [Anubis Traefik integration](https://anubis.techaro.lol/docs/admin/environments/traefik/)
- [Anubis policy reference](https://anubis.techaro.lol/docs/admin/policy/)
- [Anubis policy expressions](https://anubis.techaro.lol/docs/admin/policy/expressions/)
- [Traefik forwardAuth middleware](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/forwardauth/)
