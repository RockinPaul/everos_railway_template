#!/bin/sh
# Start EverOS (private, no auth, port 8000) and Caddy (public, bearer token, $PORT).
set -eu
: "${PORT:=8080}"
: "${EVEROS_ROOT:=/data}"
: "${EVEROS_API__PORT:=8000}"

# The public gateway is only as strong as the token: require it, a sane length, and a charset that
# cannot change Caddy's matcher semantics ('*' would turn the comparison into a prefix match, '"' breaks
# the config).
[ -n "${API_TOKEN:-}" ] || { echo "API_TOKEN is empty; refusing to expose the API without a token" >&2; exit 1; }
[ "${#API_TOKEN}" -ge 24 ] || { echo "API_TOKEN must be at least 24 characters" >&2; exit 1; }
case "$API_TOKEN" in *[!A-Za-z0-9_-]*) echo "API_TOKEN may only contain A-Z a-z 0-9 _ -" >&2; exit 1 ;; esac
# EverOS itself refuses to start without an LLM key (LLMNotConfiguredError at startup), so fail with a
# clear message instead of a restart loop.
[ -n "${EVEROS_LLM__API_KEY:-}" ] || { echo "EVEROS_LLM__API_KEY is empty; EverOS cannot start without a chat model key" >&2; exit 1; }

# Railway volumes are root-owned; hand the root to the everos user once, then drop privileges.
mkdir -p "$EVEROS_ROOT/uploads"
if [ "$(id -u)" = "0" ]; then
  [ "$(stat -c %u "$EVEROS_ROOT")" = "1000" ] || chown -R everos:everos "$EVEROS_ROOT"
  RUN_AS="setpriv --reuid=everos --regid=everos --init-groups"
  export HOME=/home/everos
else
  RUN_AS=""
fi

# The server refuses to start without <root>/everos.toml; init is idempotent and writes the
# shipped defaults, which the EVEROS_* environment overrides.
if [ ! -f "$EVEROS_ROOT/everos.toml" ] || [ ! -f "$EVEROS_ROOT/ome.toml" ]; then
  $RUN_AS everos init --root "$EVEROS_ROOT" >/dev/null
  echo "initialized EverOS root at $EVEROS_ROOT"
fi

# Caddy runs in the background; a watchdog takes the whole container down if it dies, so Railway
# restarts us instead of leaving a live container with a dark public port.
$RUN_AS caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
$RUN_AS caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
CADDY_PID=$!
( while kill -0 "$CADDY_PID" 2>/dev/null; do sleep 5; done; echo "caddy exited; stopping the container" >&2; kill -TERM 1 ) &

exec $RUN_AS everos server start --root "$EVEROS_ROOT" --port "$EVEROS_API__PORT"
