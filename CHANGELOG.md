# Changelog

## 2026-09 — initial release, EverOS 1.3.1

- One service built from `Dockerfile`: `python:3.12.14-slim`, `everos[multimodal]==1.3.1` from PyPI, Caddy 2.11.4 binary. No LibreOffice (office uploads return 503).
- `entrypoint.sh`: refuses to start without an `API_TOKEN` of at least 24 characters from `A-Z a-z 0-9 _ -` or without `EVEROS_LLM__API_KEY`, hands the volume to the `everos` user (only when not yet owned) and drops privileges, runs `everos init` once when the config files are missing, validates and starts Caddy on `PORT` with a watchdog that stops the container if Caddy dies, and runs EverOS on `:8000` (IPv4 and IPv6) as PID 1.
- `Caddyfile`: `/health` and CORS preflights open, everything else requires `Authorization: Bearer <API_TOKEN>` (401 JSON otherwise) with a 64 MB body limit; the private port 8000 stays unauthenticated for the official plugins.
- Defaults: OpenRouter `openai/gpt-4.1-mini` for extraction, `google/gemini-3.8-flash` for multimodal with the same key, `file://` reads restricted to `/data/uploads`, JSON logs.
- Volume `/data`; healthcheck `/health`.

### Upgrading an existing deployment

Bump `EVEROS_VERSION` in `Dockerfile`. The update redeploys the service; the volume, including memories and indexes, is kept. Read upstream's changelog for schema changes: EverOS creates new SQLite tables on start but does not alter existing ones, so follow upstream's migration notes when a release changes columns; the LanceDB index is rebuildable from the Markdown files.
