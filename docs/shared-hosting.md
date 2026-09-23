# Shared hosting notes

## Protocols

| Scheme | Meaning | Typical port |
|--------|---------|--------------|
| `ftpes://` | **Explicit FTPS** — connect plain, then `AUTH TLS` | 21 |
| `ftps://` | **Implicit FTPS** — TLS from the first byte | 990 |
| `sftp://` | SSH file transfer (not FTP) | 22 |
| `ftp://` | Cleartext FTP — avoid | 21 |

Most cPanel / shared hosts want **explicit FTPS**. Prefer `ftpes://` in `.env.deploy`.

This toolkit’s `lftp` path rewrites `ftpes://` to `ftp://` and sets `ftp:ssl-force` because some `lftp` builds do not accept the `ftpes` URL scheme.

## Remote path layout

`FTP_REMOTE_DIR` is the **parent** only (e.g. `/pub` or `/public_html`).

The deploy script creates and mirrors into:

```text
<FTP_REMOTE_DIR>/<app-name>/
```

where `<app-name>` defaults to the basename of `--root` (override with `DEPLOY_APP_NAME`).

If you set `FTP_REMOTE_DIR=/pub/my-app` and the app folder is also `my-app`, the script detects the duplicate and does **not** create `/pub/my-app/my-app`. Prefer keeping `FTP_REMOTE_DIR=/pub` so the rule stays obvious.

### What went wrong before

If `cd` into the app folder fails and the script continues, `mirror` uploads into the **current** remote directory (often `/pub` itself). Always `mkdir -p` the absolute app path, `cd` into it, print `pwd`, then mirror. This toolkit does that and only enables `cmd:fail-exit` after navigation.

## Web docroot

Many PHP apps keep the project root privately and expose only `public/`:

```text
/pub/stock-overlay/           # full project on disk
/pub/stock-overlay/public/    # document root for https://apps.example.com/stock-overlay/
```

Set `DEPLOY_DOCROOT=public` (default) so the deploy summary reminds you. For apps where the repo root *is* the docroot, set `DEPLOY_DOCROOT=` (empty).

## Runtime data

SQLite and upload dirs must be **writable** on the host and usually **not** overwritten by deploy. Default excludes skip `data/` and `*.sqlite*`. After mirror, `DEPLOY_ENSURE_DIRS` (default `data`) creates empty dirs on the remote if missing.

## App URL paths

Deploying under `/app-name/` does not fix root-absolute URLs in the app (`/assets/...`, `fetch('/api/...')`). Those must be relative or prefixed with a base path in the **application** code. This toolkit only moves files.
