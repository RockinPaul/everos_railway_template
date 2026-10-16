# Changelog

## 2026-10-16 — EverOS 1.4.2

- `EVEROS_VERSION` 1.4.1 → 1.4.2. Same dependency set (openai 2.54.0, lancedb 0.34.0, pyarrow 26.0.0).
- **Long-running servers stop leaking file descriptors.** 1.4.1 kept a LanceDB index reader for every index version it ever opened, so the open-file count grew for the life of the process; upstream measured a server on a 1024-descriptor limit running out within hours. 1.4.2 caps both caches.
- **Memories in two projects no longer overwrite each other in the index.** Index rows were keyed on `id`, which is unique only within one `project_id`, so a user's memories written under a second project replaced the first project's in search (the Markdown files were never affected). Reproduced locally on 1.4.1: after `alice` got a memory in project `beta`, her memory in project `alpha` no longer came back from search.
- Searches no longer wait behind background embedding work: queries get their own budget (`[embedding].query_max_concurrent`, default 4), and the background default rises from 5 to 10, so up to 14 embedding requests can be in flight at once. Lower `EVEROS_EMBEDDING__MAX_CONCURRENT` if your provider rate-limits.
- The index is optimized at most once a minute (was every ten seconds), so a new memory can take up to a minute longer to show up in keyword search.
- Hardening: `PATCH /knowledge/documents/{id}` with category `..` could move a document out of `knowledge/`, where it was no longer found. Only a caller holding the API token could do this.

### Upgrading an existing deployment

Nothing to do beyond the redeploy. On its first start 1.4.2 re-checks every indexed Markdown file against the index once and re-embeds only the rows that were lost, so a root where two projects overwrote each other repairs itself. Verified locally: the 1.4.1 volume from the reproduction above, upgraded in place, returned `alpha`'s memory again alongside `beta`'s, and new memories in new projects were stored and found. The pass reads every file once, so the first start takes longer on a large root. If you ran reflection across several projects before this update, upstream recommends running `everos cascade rebuild` once; it refuses to run while the server is up, and the entrypoint never runs it for you. A fresh deploy passes the same add, flush and search check as 1.4.1, and requests without the token still get 401.

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
