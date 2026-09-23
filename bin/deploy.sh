#!/usr/bin/env bash
# Publish an app directory to shared hosting via lftp (FTPS / SFTP).
# Usage:
#   shared-host-deploy/bin/deploy.sh --root /path/to/app
#   shared-host-deploy/bin/deploy.sh          # uses cwd
#
# Credentials: <root>/.env.deploy (see templates/.env.deploy.example)

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: deploy.sh [--root <app-dir>]

  --root DIR   App directory to mirror (default: current working directory).
               Loads DIR/.env.deploy for FTP_* settings.

Environment (from .env.deploy):
  FTP_HOST          ftpes:// | ftps:// | sftp:// | ftp:// host URL
  FTP_USER          username
  FTP_PASS          password
  FTP_REMOTE_DIR    parent remote directory (e.g. /pub) — app name is appended
  FTP_DELETE        1 to remove remote files missing locally (default: 0)
  DEPLOY_APP_NAME   override remote folder name (default: basename of --root)
  DEPLOY_DOCROOT    web docroot under the app (default: public; empty to skip hint)
  DEPLOY_ENSURE_DIRS  space-separated dirs to mkdir on remote after mirror (default: data)
  DEPLOY_EXCLUDE_GLOBS  extra space-separated exclude globs for mirror
EOF
}

ROOT="$(pwd)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v lftp >/dev/null 2>&1; then
  echo "lftp is required but not installed." >&2
  exit 1
fi

ENV_FILE="${DEPLOY_ENV_FILE:-$ROOT/.env.deploy}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  echo "Copy shared-host-deploy/templates/.env.deploy.example to the app as .env.deploy and fill in credentials."
  exit 1
fi

# shellcheck disable=SC1090
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

: "${FTP_HOST:?Set FTP_HOST in .env.deploy}"
: "${FTP_USER:?Set FTP_USER in .env.deploy}"
: "${FTP_PASS:?Set FTP_PASS in .env.deploy}"
: "${FTP_REMOTE_DIR:?Set FTP_REMOTE_DIR in .env.deploy}"

APP_NAME="${DEPLOY_APP_NAME:-$(basename "$ROOT")}"
PARENT_DIR="${FTP_REMOTE_DIR%/}"
if [[ "$(basename "$PARENT_DIR")" == "$APP_NAME" ]]; then
  REMOTE_APP_DIR="$PARENT_DIR"
else
  REMOTE_APP_DIR="${PARENT_DIR}/${APP_NAME}"
fi

FTP_DELETE="${FTP_DELETE:-0}"
DELETE_ARGS=()
if [[ "$FTP_DELETE" == "1" ]]; then
  DELETE_ARGS=(--delete)
fi

# Default docroot hint for PHP-style apps; set DEPLOY_DOCROOT= to disable.
DEPLOY_DOCROOT="${DEPLOY_DOCROOT-public}"
DEPLOY_ENSURE_DIRS="${DEPLOY_ENSURE_DIRS-data}"

EXCLUDE_ARGS=(
  --exclude-glob '.git/'
  --exclude-glob '.gitignore'
  --exclude-glob '.env'
  --exclude-glob '.env.*'
  --exclude-glob '.cursor/'
  --exclude-glob 'data/'
  --exclude-glob '*.sqlite'
  --exclude-glob '*.sqlite-*'
  --exclude-glob '.DS_Store'
  --exclude-glob 'node_modules/'
  --exclude-glob 'vendor/'
  --exclude-glob '.env.deploy'
  --exclude-glob '.env.deploy.example'
  --exclude-glob 'scripts/deploy.sh'
)

# shellcheck disable=SC2206
EXTRA_GLOBS=( ${DEPLOY_EXCLUDE_GLOBS:-} )
for g in "${EXTRA_GLOBS[@]+"${EXTRA_GLOBS[@]}"}"; do
  [[ -n "$g" ]] || continue
  EXCLUDE_ARGS+=(--exclude-glob "$g")
done

SSL_CMDS=$'set ssl:verify-certificate no\n'
# Some lftp builds reject ftpes:// as a URL scheme; rewrite to ftp:// + ssl-force.
OPEN_HOST="$FTP_HOST"
case "$FTP_HOST" in
  ftpes://*)
    OPEN_HOST="ftp://${FTP_HOST#ftpes://}"
    SSL_CMDS+=$'set ftp:ssl-force true\nset ftp:ssl-protect-data true\nset ftp:ssl-protect-list true\n'
    ;;
  ftps://*)
    SSL_CMDS+=$'set ftp:ssl-force true\nset ftp:ssl-protect-data true\nset ftp:ssl-protect-list true\n'
    ;;
  sftp://*)
    SSL_CMDS=""
    ;;
  ftp://*)
    echo "Warning: plain ftp:// is unencrypted. For explicit FTPS use ftpes://host" >&2
    SSL_CMDS=""
    ;;
  *)
    echo "Warning: unrecognized FTP_HOST scheme in $FTP_HOST" >&2
    ;;
esac

ENSURE_CMDS=""
# shellcheck disable=SC2206
ENSURE_LIST=( ${DEPLOY_ENSURE_DIRS} )
for d in "${ENSURE_LIST[@]+"${ENSURE_LIST[@]}"}"; do
  [[ -n "$d" ]] || continue
  ENSURE_CMDS+="mkdir -p ${d}"$'\n'
done

# Build exclude lines for the lftp command string.
EXCLUDE_LINES=""
for a in "${EXCLUDE_ARGS[@]}"; do
  EXCLUDE_LINES+="  ${a} \\"$'\n'
done

echo "Deploying $ROOT → ${FTP_HOST}${REMOTE_APP_DIR}"

# Navigate with fail-exit off so existing dirs are OK; re-enable before mirror.
lftp -e "
${SSL_CMDS}
set net:max-retries 3
set net:timeout 20
open -u ${FTP_USER},${FTP_PASS} ${OPEN_HOST}
lcd ${ROOT}
set cmd:fail-exit false
mkdir -p ${REMOTE_APP_DIR}
cd ${REMOTE_APP_DIR}
pwd
set cmd:fail-exit true
mirror -R --verbose --parallel=4 \
  ${DELETE_ARGS[*]+"${DELETE_ARGS[*]}"} \
${EXCLUDE_LINES}  ./ ./
${ENSURE_CMDS}bye
"

echo "Done. Remote app path: ${REMOTE_APP_DIR}"
if [[ -n "$DEPLOY_DOCROOT" ]]; then
  echo "Point the site URL /${APP_NAME}/ at remote ${REMOTE_APP_DIR}/${DEPLOY_DOCROOT}/"
  echo "Ensure writable runtime dirs exist on the host (e.g. data/ for SQLite)."
fi
