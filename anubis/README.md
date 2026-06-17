# Anubis

This stack runs [Anubis](https://anubis.techaro.lol/) as a shared AI-bot firewall. Anubis sits in front of any Traefik-proxied service and issues a proof-of-work challenge to suspicious clients before they reach the application. It is exposed as a Traefik [`forwardAuth`](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/forwardauth/) middleware called `anubis@file`, so any stack in this repository can opt into bot protection with a one-line `TRAEFIK_ACCESS_POLICY` change.

## How the integration works

The default flow is **in-site**: Anubis is not exposed on a public hostname of its own. The Traefik file-provider config in [`traefik/config/dynamic/anubis.yml.dist`](../traefik/config/dynamic/anubis.yml.dist) defines three objects:

- `anubis@file` — the `forwardAuth` middleware that calls Anubis on the shared `traefik` network at `http://anubis:8923/.within.website/x/cmd/anubis/api/check`.
- `anubis-static@file` — a low-priority catch-all router that matches `PathPrefix("/.within.website/")` on `websecure` and serves the Anubis challenge page and its static assets. The Anubis 401 response body is HTML that references same-origin assets under `/.within.website/` (CSS, JS for the PoW solver); this catch-all routes those requests to Anubis.
- `anubis@file` (service) — the upstream that both the forwardAuth middleware and the catch-all router talk to.

When a request hits a protected stack, Traefik runs the middlewares in the order they appear in the router's `middlewares:` list. The `forwardAuth` middleware proxies the request to Anubis, which inspects the policy file. If the policy says `ALLOW`, Traefik forwards the original request to the application. If the policy says `CHALLENGE`, Anubis returns HTTP 401 with the challenge HTML; Traefik passes that 401 (and the body) to the browser, which then loads the same-origin challenge assets via the `anubis-static` catch-all router.

The challenge HTML uses **relative URLs** for its form `action=` and asset references. The browser resolves them to the protected host the user is actually on (`forgejo.example.com`, `woodpecker.example.com`, etc.), so a single Anubis instance works for an arbitrary number of protected hosts without per-host config. Each protected host is its own origin from the cookie's perspective, which means the user solves the challenge once per host. This is by design: it keeps the cookie scoped to a single origin and avoids any cross-host trust surface.

Middleware order matters: ALL middlewares in the list run on every request. The existing `default-access@file` middleware in this repo is an `ipAllowList`; when it returns 403, Traefik short-circuits the request and Anubis never sees it. Anubis only ever sees requests that pass the `ipAllowList`. A request from a client in the allow list still goes through both Anubis and the application — there is no implicit "LAN clients skip the challenge" behaviour. The Anubis policy file is the only place to express that kind of exemption.

## Quick start

```shell
cp .env.dist .env
cp config/policy.yml.dist config/policy.yml
nano -w .env
docker compose up -d
```

The default `.env` has no required values beyond `IMAGE_TAG` (defaults to `latest`) and the bind/network knobs. After `docker compose up -d`, Anubis is reachable on the shared `traefik` network as `anubis:8923` and on `127.0.0.1:8923` on the host for direct verification and debugging.

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
2. Edit `config/policy.yml` and add a rule under the `# Per-stack exemptions` section, modelled on the example block:

    ```yaml
    - name: forgejo-webhooks-exempt
      expression:
        all:
          - host == "forgejo.example.com"
          - path.startsWith("/api/webhooks")
      action: ALLOW
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
```

## Advanced: Anubis on a separate public host (cross-origin challenge)

The default in-site flow is sufficient for the vast majority of deployments. A **separate-host** flow (Anubis on its own public hostname, e.g. `anubis.example.com`, with the challenge served from that origin and the user redirected back to the protected host on success) is not implemented yet in this repository. The compose `traefik_exposed` variant, the `Host(`${TRAEFIK_HOST}`)` Traefik labels, and the cross-origin cookie handling are the work tracked by the linked issue.

For documentation purposes, the variables the future `traefik_exposed` variant would consume and **why** each one matters:

- `TRAEFIK_HOST` — the public hostname Anubis itself is reachable on, for example `anubis.example.com`. Traefik issues a Let's Encrypt certificate for this host and serves Anubis on `https://anubis.example.com/`.
- `REDIRECT_DOMAINS` — a security allowlist. After a successful challenge, Anubis only redirects the browser to a hostname that appears in this list. Without it, Anubis would behave as an open redirector and could be abused for phishing. It must list **every** public hostname Anubis protects (for example `forgejo.example.com,woodpecker.example.com,castopod.example.com`). Operators running a single Anubis instance to protect a dozen stacks must enumerate all twelve in this list.
- `PUBLIC_URL` — the absolute origin the Anubis challenge page is served from. The Anubis container uses it to build the form `action=` URL and the success redirect target. It must point at the public host you will expose Anubis on, including scheme, with no trailing slash, for example `https://anubis.example.com`. In a single-instance setup this is the same as `TRAEFIK_HOST` with the scheme.
- `COOKIE_DOMAIN` — scopes the Anubis cookie across subdomains. A leading dot means the cookie is shared across all subdomains of the parent domain, for example `.example.com` covers `forgejo.example.com` and `woodpecker.example.com`. Without it, users have to solve the challenge on every subdomain.

None of these are needed for the default in-site flow, and the default `.env.dist` only references them in a commented "Advanced" section at the bottom. The Anubis image, policy file, and forwardAuth middleware are unchanged between the two flows; the only thing the separate-host flow adds is the cross-origin challenge and the open-redirector surface that comes with it.

Tracking issue: <https://git.skobk.in/skobkin/docker-stacks/issues/333>.

## References

- [Anubis project home](https://anubis.techaro.lol/)
- [Anubis Traefik integration](https://anubis.techaro.lol/docs/admin/environments/traefik/)
- [Anubis policy reference](https://anubis.techaro.lol/docs/admin/policy/)
- [Anubis policy expressions](https://anubis.techaro.lol/docs/admin/policy/expressions/)
- [Traefik forwardAuth middleware](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/forwardauth/)
