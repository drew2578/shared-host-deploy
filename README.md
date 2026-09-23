# shared-host-deploy

Reusable **lftp** publish toolkit for apps on shared hosting (explicit FTPS, implicit FTPS, or SFTP).

Point a coding agent at this repo when you need to publish to cPanel-style FTP hosts. Agent checklist: [AGENTS.md](AGENTS.md). Hosting details: [docs/shared-hosting.md](docs/shared-hosting.md).

## Quick start

```bash
# 1. Clone next to your apps (or anywhere)
git clone https://github.com/drew2578/shared-host-deploy.git ~/projects/shared-host-deploy

# 2. In the app repo
cp ~/projects/shared-host-deploy/templates/.env.deploy.example .env.deploy
# edit .env.deploy — FTP_REMOTE_DIR is the PARENT only (e.g. /pub)

# 3. Publish
~/projects/shared-host-deploy/bin/deploy.sh --root ~/projects/my-app
```

Requires [`lftp`](https://lftp.yar.ru/).

## Layout

```text
bin/deploy.sh                 # entrypoint
templates/.env.deploy.example
templates/gitignore.snippet
AGENTS.md                     # instructions for coding agents
docs/shared-hosting.md
```

## Remote path rule

```text
FTP_REMOTE_DIR=/pub          # parent
app folder name = stock-overlay
→ uploads to /pub/stock-overlay/
```

For PHP apps with a `public/` web root, map `https://apps.example.com/stock-overlay/` to `/pub/stock-overlay/public/`.

## License

MIT
