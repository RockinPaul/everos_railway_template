# Changelog

## 2026-09 — initial release, EverOS 1.3.1

- One service built from `Dockerfile`: `python:3.12-slim`, `everos[multimodal]==1.3.1` from PyPI, Caddy 2 binary. No LibreOffice (office uploads return 503).
- `entrypoint.sh`: refuses to start without an `API_TOKEN` of at least 24 characters, hands the volume to the `everos` user and drops privileges, runs `everos init` once when `/data/everos.toml` is missing, starts Caddy on `PORT` and EverOS on `:8000` (IPv4 and IPv6).
- `Caddyfile`: `/health` open, everything else requires `Authorization: Bearer <API_TOKEN>`, 401 JSON otherwise; the private port 8000 stays unauthenticated for the official plugins.
- Defaults: OpenRouter `openai/gpt-4.1-mini` for extraction, `google/gemini-3.8-flash` for multimodal with the same key, `file://` reads restricted to `/data/uploads`, JSON logs.
- Volume `/data`; healthcheck `/health`.

### Upgrading an existing deployment

Bump `EVEROS_VERSION` in `Dockerfile`. The update redeploys the service; the volume, including memories and indexes, is kept. Read upstream's changelog for schema changes: the SQLite state database migrates automatically on start, and the LanceDB index is rebuildable from the Markdown files.
