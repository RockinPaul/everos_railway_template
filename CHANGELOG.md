# Changelog

## 2026-10 — EverOS 1.4.1

- `EVEROS_VERSION` 1.3.1 → 1.4.1. 1.3.1 declares `openai>=1.0.0` with no ceiling, so every build since 2026-09-24 has installed the openai 3.x line that upstream never tested (3.29.0 on 2026-10-13). That build still extracts and searches, but openai 3.19.2 failed every LLM and embedding call, so the next 3.x release could too. 1.4.1 pins `openai<3`; the image now gets openai 2.54.0.
- From 1.4.0: vector columns get an IVF_FLAT index once they hold 2000 rows (`EVEROS_LANCEDB__VECTOR_INDEX_MIN_ROWS`), `[cascade] scan_interval_seconds` is a setting, `cascade sync` / `fix --apply` / `rebuild` refuse to run next to a live server (exit 3), pyarrow ≥ 25.0.1, and `POST /memory/add` answers 422 for a `role: "tool"` message without `tool_call_id`.

### Upgrading an existing deployment

Nothing to do beyond the redeploy. The first start after the update builds vector indexes on tables past 2000 rows (about 1.4 s per column at 100k rows) while search keeps working. Upstream's `LanceDBSchemaMismatchError` note only concerns stores older than 1.1.1; this template started at 1.3.1. The entrypoint never calls `everos cascade`, so the new exit code does not affect it.

## 2026-09 — initial release, EverOS 1.3.1

- One service built from `Dockerfile`: `python:3.12.14-slim`, `everos[multimodal]==1.3.1` from PyPI, Caddy 2.11.4 binary. No LibreOffice (office uploads return 503).
- `entrypoint.sh`: refuses to start without an `API_TOKEN` of at least 24 characters from `A-Z a-z 0-9 _ -` or without `EVEROS_LLM__API_KEY`, hands the volume to the `everos` user (only when not yet owned) and drops privileges, runs `everos init` once when the config files are missing, validates and starts Caddy on `PORT` with a watchdog that stops the container if Caddy dies, and runs EverOS on `:8000` (IPv4 and IPv6) as PID 1.
- `Caddyfile`: `/health` and CORS preflights open, everything else requires `Authorization: Bearer <API_TOKEN>` (401 JSON otherwise) with a 64 MB body limit; the private port 8000 stays unauthenticated for the official plugins.
- Defaults: OpenRouter `openai/gpt-4.1-mini` for extraction, `google/gemini-3.8-flash` for multimodal with the same key, `file://` reads restricted to `/data/uploads`, JSON logs.
- Volume `/data`; healthcheck `/health`.

### Upgrading an existing deployment

Bump `EVEROS_VERSION` in `Dockerfile`. The update redeploys the service; the volume, including memories and indexes, is kept. Read upstream's changelog for schema changes: EverOS creates new SQLite tables on start but does not alter existing ones, so follow upstream's migration notes when a release changes columns; the LanceDB index is rebuildable from the Markdown files.
