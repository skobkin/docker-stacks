# Anubis

This stack runs [Anubis](https://anubis.techaro.lol/) as a shared AI-bot firewall. Anubis sits in front of any Traefik-proxied service and issues a proof-of-work challenge to suspicious clients before they reach the application. It is exposed as a Traefik [`forwardAuth`](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/forwardauth/) middleware called `anubis@file`, so any stack in this repository can opt into bot protection with a one-line `TRAEFIK_ACCESS_POLICY` change.

## Quick start

```shell
cp .env.dist .env
cp config/policy.yml.dist config/policy.yml
nano -w .env
docker compose up -d
```

Before starting Anubis, set the required operational values in `.env`:

- `REDIRECT_DOMAINS` — comma-separated list of hostnames that Anubis should redirect back to after a successful challenge.
- `PUBLIC_URL` — the public URL Anubis uses when rendering challenge pages and absolute redirect URLs.
- `COOKIE_DOMAIN` — the parent domain that the Anubis cookie should be valid on, for example `.example.com` to cover multiple subdomains.

For a single host:

```dotenv
REDIRECT_DOMAINS=app.example.com
PUBLIC_URL=https://app.example.com
COOKIE_DOMAIN=.example.com
```

After `docker compose up -d`, Anubis is reachable on the shared `traefik` network as `anubis:8923`. It also binds to `127.0.0.1:8923` on the host for direct verification and debugging.

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

The order in the list is the order the middlewares run. Anubis is an access decision and is usually placed after the access-list middlewares so trusted LAN clients bypass the challenge.

## Excluding paths from Anubis (per stack)

The Anubis instance is shared, so path exemptions are expressed as policy-file rules that match the request's `host` against the protected stack's `TRAEFIK_HOST`. To exempt a path for a specific stack:

1. Find the stack's `TRAEFIK_HOST` from its `.env` (for example `app.example.com`) and the path prefixes you want to exempt (for example `/api/webhooks` and `/.well-known/acme-challenge`).
2. Edit `config/policy.yml` and add a rule under the `# Per-stack exemptions` section, modelled on the example block:

    ```yaml
    - name: app-webhooks-exempt
      expression:
        all:
          - host == "app.example.com"
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
    curl -I https://app.example.com/api/webhooks
    ```

    The response should come from the application, not the Anubis challenge page. A request to a non-exempt path on the same host (`curl -I https://app.example.com/`) should still return the Anubis challenge, which proves the exemption is scoped to the chosen paths only.

Common exemption patterns:

- Webhook receivers (`/api/webhooks`, `/hooks`) for GitHub, Stripe, or other third-party callbacks.
- ACME HTTP-01 challenges (`/.well-known/acme-challenge`) so Let's Encrypt validation does not get challenged.
- Health-check endpoints (`/healthz`, `/readyz`) for uptime monitors that do not solve challenges.
- Matrix federation endpoints (`/_matrix/federation/*`) for server-to-server traffic.

The Anubis policy expression language supports more conditions than `host ==` and `path.startsWith(...)`. See the [Anubis policy expressions documentation](https://anubis.techaro.lol/docs/admin/policy/expressions/) for the full reference, including `path_regex`, `user_agent_regex`, `remote_address`, and nested `any`/`all`/`not` blocks.

## Customization recommendations

- **Tune challenge difficulty.** The `DIFFICULTY` environment variable (4 by default) controls the proof-of-work cost. Increase it to slow down scrapers further; decrease it when legitimate users complain about slow challenges. See the [Anubis configuration documentation](https://anubis.techaro.lol/docs/).
- **Set `COOKIE_DOMAIN` for cross-subdomain SSO.** When multiple stacks share a parent domain (for example `app.example.com` and `other.example.com`), a cookie domain of `.example.com` lets a single solved challenge cover every subdomain. Without it, users have to solve the challenge again on each subdomain.
- **Use a custom policy file for known-good bots.** The default policy challenges every client. To allow specific bots (search engine crawlers, uptime monitors, RSS readers) without a challenge, add `user_agent_regex` matches with `action: ALLOW` at the top of the policy file. See the [Anubis policy documentation](https://anubis.techaro.lol/docs/admin/policy/).
- **Allowlist trusted subnets.** Office, VPN, or monitoring subnets can be exempt from the challenge by adding a rule with `remote_address` or by combining Anubis with the existing `default-access@file` middleware (which already runs first when `TRAEFIK_ACCESS_POLICY=default-access@file,anubis@file`).
- **Pin the image tag for reproducibility.** The default `IMAGE_TAG=latest` rolls forward. Set a specific version in `.env` if you want reproducible builds.
- **Watch the Anubis logs.** Anubis logs challenge decisions to stdout. Increase the log retention by raising `LOG_MAX_FILE` or `LOG_MAX_SIZE` in `.env` when investigating.
- **Forward only the headers Anubis needs.** The included `anubis.yml.dist` forwards the same set of request headers as the Authelia forwardAuth middleware. Do not forward `Authorization`; Anubis does not consume it and leaking it can interfere with Traefik's normal auth handling.
- **Consider the `TARGET` environment variable for redirect-mode operation.** When `TARGET` is set to a non-empty value (the variable takes a trailing space when the upstream expects a blank target), Anubis sends users back to the original URL after a successful challenge rather than rendering the challenge page inline. See the [Anubis Traefik integration guide](https://anubis.techaro.lol/docs/admin/environments/traefik/).

## Verifying the setup

After the Anubis stack is up and the Traefik forwardAuth middleware is in place, check the wiring:

```shell
# Anubis forwardAuth endpoint is reachable from the host.
curl -I http://127.0.0.1:8923/.within.website/x/cmd/anubis/api/check
# A protected stack returns the Anubis challenge instead of the application.
curl -I https://app.example.com/
# A path exempt in policy.yml returns the application response.
curl -I https://app.example.com/api/webhooks
```

## References

- [Anubis project home](https://anubis.techaro.lol/)
- [Anubis Traefik integration](https://anubis.techaro.lol/docs/admin/environments/traefik/)
- [Anubis policy reference](https://anubis.techaro.lol/docs/admin/policy/)
- [Anubis policy expressions](https://anubis.techaro.lol/docs/admin/policy/expressions/)
- [Traefik forwardAuth middleware](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/forwardauth/)
