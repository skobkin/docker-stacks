# Remark42

Remark42 is a self-hosted comment engine. This stack stores data in `./data`,
binds the HTTP service to `127.0.0.1:8388` by default, and can optionally be
exposed through Traefik.

## Installation

Copy the env template and edit the required values:

```shell
cp .env.dist .env
```

Required settings:

- `REMARK_URL`: public URL of this Remark42 instance.
- `SITE`: comma-separated site IDs allowed to use this instance.
- `SECRET`: long random secret used to sign tokens.
- At least one auth method, for example GitHub, Google, Discord, Telegram,
  email, or anonymous auth.

Open `${REMARK_URL}/web` after startup to run Remark42's built-in smoke test.
Include the `remark` site ID in `SITE` if you want to use that demo page.

See the upstream [installation documentation](https://remark42.com/docs/getting-started/installation/)
and [configuration parameter list](https://remark42.com/docs/configuration/parameters/).

## Traefik

See the [common Traefik guide](../_docs/traefik.md).

Other reverse proxy examples:

- [Nginx](https://remark42.com/docs/manuals/nginx/)
- [Reproxy](https://remark42.com/docs/manuals/reproxy/)

## ntfy Notifications

Remark42 can send admin webhook notifications for new comments. The `.env.dist`
template includes a commented ntfy example using ntfy JSON publishing so the
Remark42 webhook template can set the `topic`, `title`, `message`, and `click`
fields in the request body.

For JSON publishing, set `NOTIFY_WEBHOOK_URL` to the ntfy root URL, such as
`https://ntfy.example.com/`, not a topic URL like `/remark42`. The topic belongs
inside `NOTIFY_WEBHOOK_TEMPLATE`.

To send original comment Markdown instead of Remark42's rendered HTML, use
`.Orig` for the message and add the `Markdown:yes` ntfy header, as shown in
`.env.dist`. This sends raw user-authored Markdown to ntfy. Treat it as
user-supplied content: notification clients may fetch linked images or expose
link previews, so Markdown notifications can leak client IPs or other metadata
to third-party URLs included in comments.

Keep the `Authorization` header unless the target ntfy topic allows anonymous
writes. The repo's `ntfy` stack defaults to private access, so create a limited
notifier user or token with write access to the chosen topic before enabling the
Remark42 webhook.

## Import From WordPress

Export comments from WordPress using the standard WordPress export flow, then
copy the XML file into `./data` on the Remark42 host. That directory is mounted
as `/srv/var` inside the container.

Enable `ADMIN_PASSWD` in `.env` for the import, restart Remark42, and run:

```shell
docker exec -it remark42 import -p wordpress -f /srv/var/wordpress-export.xml -s remark
```

Replace `wordpress-export.xml` and `remark` with your export file and `SITE`
value. The upstream import command removes existing comments for the target
site, so make a backup first if the site already has Remark42 comments.

Check [migration documentation](https://remark42.com/docs/backup/migration/) for more details.
