#!/bin/sh
# Start EverOS (private, no auth, port 8000) and Caddy (public, bearer token, $PORT).
set -eu
: "${PORT:=8080}"
: "${EVEROS_ROOT:=/data}"
: "${EVEROS_API__PORT:=8000}"

[ -n "${API_TOKEN:-}" ] || { echo "API_TOKEN is empty; refusing to expose the API without a token" >&2; exit 1; }
[ "${#API_TOKEN}" -ge 24 ] || { echo "API_TOKEN must be at least 24 characters" >&2; exit 1; }
[ -n "${EVEROS_LLM__API_KEY:-}" ] || echo "warning: EVEROS_LLM__API_KEY is empty; memory extraction will fail until it is set" >&2

# Railway volumes are root-owned; hand the root to the everos user, then drop privileges.
mkdir -p "$EVEROS_ROOT/uploads"
if [ "$(id -u)" = "0" ]; then
  chown -R everos:everos "$EVEROS_ROOT"
  RUN_AS="setpriv --reuid=everos --regid=everos --init-groups"
  export HOME=/home/everos
else
  RUN_AS=""
fi

# The server refuses to start without <root>/everos.toml; init is idempotent and writes the
# shipped defaults, which the EVEROS_* environment overrides.
if [ ! -f "$EVEROS_ROOT/everos.toml" ]; then
  $RUN_AS everos init --root "$EVEROS_ROOT" >/dev/null
  echo "initialized EverOS root at $EVEROS_ROOT"
fi

# Caddy in the background: if it dies, /health through the domain fails and Railway restarts us.
$RUN_AS caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
exec $RUN_AS everos server start --root "$EVEROS_ROOT" --port "$EVEROS_API__PORT"
