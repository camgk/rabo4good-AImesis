#!/bin/sh
# Writes the runtime config read by the Flutter app at startup.
# Runs from the nginx image entrypoint (/docker-entrypoint.d) before nginx starts.
set -eu

API_URL="${API_URL:-http://localhost:8080}"
# Strip trailing slashes and escape for JSON.
API_URL="$(printf '%s' "$API_URL" | sed -e 's:/*$::' -e 's/\\/\\\\/g' -e 's/"/\\"/g')"

printf '{"apiUrl": "%s"}\n' "$API_URL" > /usr/share/nginx/html/config.json
echo "40-write-config-json: apiUrl=$API_URL"
