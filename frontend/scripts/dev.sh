#!/usr/bin/env bash
# Local frontend development with hot reload.
#
#   frontend/scripts/dev.sh                 care-team web app + local API (in-memory, demo data)
#   frontend/scripts/dev.sh --api live      care-team web app against the Cloud Run API (shared database!)
#   frontend/scripts/dev.sh --api http://localhost:9000
#   frontend/scripts/dev.sh --app family    family app in Chrome at phone size (port 8091)
#   frontend/scripts/dev.sh --app both      both apps (second one runs in the background, log in /tmp)
#
# In the terminal: r = hot reload, R = hot restart, q = quit.
# The local API keeps everything in memory: restart it for a fresh demo. Nothing touches Firestore.
#
# Works with macOS /bin/bash 3.2 and Linux.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="web"
API="local"
WEB_PORT="${WEB_PORT:-8090}"
FAMILY_PORT="${FAMILY_PORT:-8091}"
API_PORT="${API_PORT:-8080}"
LIVE_API="${LIVE_API:-https://mock-api-wrnhijjuxa-ew.a.run.app}"

while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP="$2"; shift ;;
    --app=*) APP="${1#--app=}" ;;
    --api) API="$2"; shift ;;
    --api=*) API="${1#--api=}" ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 64 ;;
  esac
  shift
done

FLUTTER="${FLUTTER:-}"
if [ -z "$FLUTTER" ]; then
  if command -v flutter >/dev/null 2>&1; then FLUTTER="$(command -v flutter)"
  elif [ -x "$HOME/development/flutter/bin/flutter" ]; then FLUTTER="$HOME/development/flutter/bin/flutter"
  elif [ -x /opt/flutter/bin/flutter ]; then FLUTTER=/opt/flutter/bin/flutter
  else echo "flutter not found (set FLUTTER=...)" >&2; exit 1; fi
fi

# ---------------------------------------------------------------- API
start_local_api() {
  local venv="$ROOT/backend/mock_api/.venv"
  if [ ! -x "$venv/bin/uvicorn" ]; then
    local py=""
    for c in python3.14 python3.13 python3.12 /opt/homebrew/bin/python3.14 /opt/homebrew/bin/python3.13 /opt/homebrew/bin/python3.12 python3; do
      if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' 2>/dev/null; then
        py="$c"; break
      fi
    done
    [ -n "$py" ] || { echo "Python 3.12+ is needed for the local API (brew install python)" >&2; exit 1; }
    echo "==> Creating API virtualenv with $py (one-off)"
    "$py" -m venv "$venv"
    "$venv/bin/pip" install -q --upgrade pip
    "$venv/bin/pip" install -q -e "$ROOT/backend/mock_api"
  fi
  if curl -fsS "http://localhost:$API_PORT/health" >/dev/null 2>&1; then
    echo "==> Local API already running on :$API_PORT"
  else
    echo "==> Starting local API on :$API_PORT (in-memory, demo data loaded)"
    STORE=memory LOAD_DEMO_ON_START=true TOKEN_SECRET=dev-secret \
      nohup "$venv/bin/uvicorn" aimesis_mock_api.main:app --host 127.0.0.1 --port "$API_PORT" --reload \
      --reload-dir "$ROOT/backend/mock_api/src" > /tmp/aimesis-local-api.log 2>&1 &
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      curl -fsS "http://localhost:$API_PORT/health" >/dev/null 2>&1 && break
      sleep 1
    done
    curl -fsS "http://localhost:$API_PORT/health" >/dev/null || { echo "API did not start, see /tmp/aimesis-local-api.log" >&2; exit 1; }
    echo "    log: /tmp/aimesis-local-api.log (auto-reloads on backend/mock_api changes)"
  fi
}

case "$API" in
  local) start_local_api; API_URL="http://localhost:$API_PORT" ;;
  live) API_URL="$LIVE_API"; echo "!!  Using the LIVE API and the shared Firestore database: actions create real records." ;;
  http://*|https://*) API_URL="$API" ;;
  *) echo "--api must be local, live or a URL" >&2; exit 64 ;;
esac
API_URL="${API_URL%/}"

# ---------------------------------------------------------------- apps
cd "$ROOT/frontend"
"$FLUTTER" pub get >/dev/null

run_web() {
  echo "==> Care-team web app on http://localhost:$WEB_PORT  (API $API_URL)"
  cd "$ROOT/frontend/web"
  "$FLUTTER" run -d chrome --web-port "$WEB_PORT" --dart-define=API_URL="$API_URL" "$@"
}

run_family() {
  echo "==> Family app (phone size) on http://localhost:$FAMILY_PORT  (API $API_URL)"
  cd "$ROOT/frontend/ios"
  "$FLUTTER" run -d chrome --web-port "$FAMILY_PORT" --dart-define=API_URL="$API_URL" \
    --web-browser-flag=--window-size=430,932 "$@"
}

case "$APP" in
  web) run_web ;;
  family) run_family ;;
  both)
    ( run_family > /tmp/aimesis-family-dev.log 2>&1 & )
    echo "    family app log: /tmp/aimesis-family-dev.log"
    run_web ;;
  *) echo "--app must be web, family or both" >&2; exit 64 ;;
esac
