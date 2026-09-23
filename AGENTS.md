# Agent instructions: shared-host deploy

Use this repository when publishing an application to **shared hosting** over **FTPS / SFTP** with `lftp`. Do not invent a one-off FTP script if this toolkit is available.

## Preconditions

1. `lftp` is installed on the machine that will run the deploy (`command -v lftp`).
2. This toolkit is cloned somewhere reachable, e.g. `~/projects/shared-host-deploy`.
3. You are working in the **application** repository (the code to publish), not only in this toolkit.

## Setup in the app repo (once)

1. Copy [templates/.env.deploy.example](templates/.env.deploy.example) to the app as `.env.deploy`.
2. Fill in `FTP_HOST`, `FTP_USER`, `FTP_PASS`, and `FTP_REMOTE_DIR`.
3. Set `FTP_REMOTE_DIR` to the **parent** only (e.g. `/pub`). The script appends the app folder name.
4. Prefer `ftpes://` for explicit FTPS (most shared hosts).
5. Append [templates/gitignore.snippet](templates/gitignore.snippet) to the app `.gitignore` (or equivalent). **Never commit `.env.deploy` or passwords.**
6. Optional: add a thin wrapper `scripts/deploy.sh` in the app that calls this toolkit’s `bin/deploy.sh --root "$(cd "$(dirname "$0")/.." && pwd)"`.

## Deploy

```bash
/path/to/shared-host-deploy/bin/deploy.sh --root /path/to/app
```

Example when both repos are siblings under `~/projects`:

```bash
~/projects/shared-host-deploy/bin/deploy.sh --root ~/projects/stock-overlay
```

## After deploy

1. Confirm remote layout: `<FTP_REMOTE_DIR>/<app-name>/` contains the project (e.g. `public/`, `src/`, `config.php`).
2. Map the public URL `/<app-name>/` to remote `<…>/<app-name>/<docroot>/` (default docroot `public`).
3. Ensure runtime dirs (e.g. `data/`) are writable by PHP; they are excluded from upload on purpose.
4. If CSS/JS/API 404 under a subdirectory, fix **app** URL base paths — this toolkit does not rewrite application URLs. See [docs/shared-hosting.md](docs/shared-hosting.md).

## Hard rules

- Do **not** set `FTP_REMOTE_DIR` to `/pub/my-app` and also use app name `my-app` unless you understand the de-dupe logic; prefer parent `/pub`.
- Do **not** upload `.env`, `.env.deploy`, `.git`, or SQLite databases.
- Do **not** set `FTP_DELETE=1` unless the user explicitly wants remote files pruned.
- Do **not** print or commit credentials from `.env.deploy`.
- If `mirror` ran but files are in `/pub` instead of `/pub/<app>`, stop and fix remote navigation; re-run after cleanup.

## Quick reference

| Variable | Role |
|----------|------|
| `FTP_HOST` | `ftpes://host` (preferred), `ftps://`, or `sftp://` |
| `FTP_REMOTE_DIR` | Parent path only (`/pub`) |
| `DEPLOY_APP_NAME` | Override remote folder name |
| `DEPLOY_DOCROOT` | Hint path (`public` or empty) |
| `DEPLOY_ENSURE_DIRS` | Remote dirs to create after mirror (`data`) |
| `DEPLOY_EXCLUDE_GLOBS` | Extra exclude patterns |
| `FTP_DELETE` | `1` = prune remote extras |
