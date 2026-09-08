# EverOS Railway Template

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/everos?referralCode=YqmMB-&utm_medium=integration&utm_source=template&utm_campaign=generic)

Railway template for [EverOS](https://github.com/EverMind-AI/EverOS), the open-source (Apache-2.0) memory layer for AI agents: it turns conversations into durable, user-owned Markdown memories with a local index, and serves them back to any agent over an HTTP API. One service, one volume, one LLM key.

| Service | Runs | Source |
|---|---|---|
| `everos` | EverOS 1.3.1 from PyPI with the multimodal extra, behind a small Caddy gateway | `Dockerfile` |

## How access works

EverOS ships no authentication and is designed for a trusted local caller. This template therefore exposes it in two ways:

- **Public domain, token required.** Caddy listens on the service's public port. Every request except `/health` needs `Authorization: Bearer <API_TOKEN>`; the token is generated at deploy time and lives in the `API_TOKEN` variable. Use this from your own code, scripts, or clients that can send a header (for example `curl` or the Dify cloud plugin).
- **Private network, no token.** EverOS itself listens on port 8000 on Railway's private network only, at `http://everos.railway.internal:8000`. The official plugins for OpenClaw, Hermes and DeepSeek Harness only accept a base URL and send no header, so run them in a service of the same Railway project and point them at that address.

Every service in the same project can use the private port without any credential, including the destructive and costly endpoints: deleting knowledge documents, quiescing the cascade, triggering OME runs that call your LLM, and reading `/metrics`. Treat project membership as the trust boundary, and do not put untrusted services in this project.

## First steps

1. Deploy. The template asks for your `EVEROS_LLM__API_KEY` (an OpenRouter key by default; any OpenAI-compatible endpoint works by changing model and base URL). EverOS does not start without it.
2. Check the capability matrix:
   ```
   curl https://<domain>/health
   ```
3. Add a conversation and search it (timestamps are Unix milliseconds):
   ```
   TOKEN=<API_TOKEN from the service variables>
   curl -X POST https://<domain>/api/v2/memory/add -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
     -d '{"session_id":"demo","app_id":"default","project_id":"default","messages":[{"sender_id":"alice","role":"user","timestamp":1760000000000,"content":"I love climbing in Yosemite every spring."}]}'
   curl -X POST https://<domain>/api/v2/memory/flush -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"session_id":"demo","app_id":"default","project_id":"default"}'
   curl -X POST https://<domain>/api/v2/memory/search -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"query":"Yosemite","user_id":"alice","app_id":"default","project_id":"default","method":"keyword"}'
   ```
   Search needs exactly one of `user_id` or `agent_id`. The default `method` is `hybrid`, which requires an embedding provider and answers `PROVIDER_NOT_CONFIGURED` until you set one; pass `"method":"keyword"` for the one-key setup. The full API is in upstream's [api.md](https://github.com/EverMind-AI/EverOS/blob/v1.3.1/docs/api.md).
4. Optional upgrades: set the embedding variables for vector and hybrid search, the rerank variables for reranking. Without them EverOS uses keyword search and says so in `/health` under `disabled_features`.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `API_TOKEN` | generated (48 chars) | Bearer token for the public domain. At least 24 characters from `A-Z a-z 0-9 _ -`; the container refuses to start otherwise (other characters would weaken or break Caddy's matcher). |
| `EVEROS_LLM__API_KEY` | you provide it | Key for the chat model that extracts memories. Required: EverOS itself refuses to start without it, so the container exits with a clear message. |
| `EVEROS_LLM__MODEL`, `EVEROS_LLM__BASE_URL` | `openai/gpt-4.1-mini`, OpenRouter | Any OpenAI-compatible chat endpoint. |
| `EVEROS_MULTIMODAL__API_KEY` | `${{EVEROS_LLM__API_KEY}}` | Vision model key for images, PDFs and audio; defaults to the same OpenRouter key. |
| `EVEROS_MULTIMODAL__MODEL`, `EVEROS_MULTIMODAL__BASE_URL` | `google/gemini-3.8-flash`, OpenRouter | Must accept OpenAI `image_url` parts. |
| `EVEROS_EMBEDDING__MODEL`, `EVEROS_EMBEDDING__API_KEY`, `EVEROS_EMBEDDING__BASE_URL` | empty (optional) | OpenAI-compatible `/embeddings`; enables vector and hybrid search, reflection and skills. |
| `EVEROS_RERANK__MODEL`, `EVEROS_RERANK__API_KEY`, `EVEROS_RERANK__BASE_URL` | empty (optional) | OpenAI-compatible `/rerank`. |
| `EVEROS_MULTIMODAL__FILE_URI_ALLOW_DIRS` | `["/data/uploads"]` | Directories `file://` content items may read. Keep it narrow: the API is reachable from outside. |
| `EVEROS_LOG_FORMAT`, `EVEROS_LOG_LEVEL` | `json`, `INFO` | |
| `PORT` | `8080` | Caddy's public port. EverOS itself is fixed on 8000 (`EVEROS_API__PORT`). |

Everything else in upstream's `everos.toml` can be overridden with `EVEROS_<SECTION>__<KEY>` variables on the service; see upstream's [configuration guide](https://github.com/EverMind-AI/EverOS/blob/v1.3.1/docs/configuration.md).

## How it fits together

- The image installs `everos[multimodal]==1.3.1` from PyPI on `python:3.12-slim` and copies the Caddy binary from the official image. Office documents (DOC, PPT, XLS) would also need LibreOffice, which is not installed; those uploads return 503 as upstream documents.
- On start the container hands the root-owned volume to the `everos` user and drops privileges. If `/data/everos.toml` is missing it runs `everos init` once (the server refuses to start without the file; the shipped defaults are overridden by the environment). Then EverOS starts on `:8000` on both IPv4 and IPv6 (an empty `EVEROS_API__HOST`), and Caddy on `PORT`.
- Data layout on the volume: Markdown memories under `/data`, the SQLite state database and LanceDB indexes under `/data/.index/`, uploads under `/data/uploads`. Back up the volume to keep the memories; the index is rebuildable.
- Healthcheck `/health` goes through Caddy to EverOS. Railway only runs it at deploy time, so the entrypoint also watches Caddy: if the gateway dies, the container stops and Railway's restart policy brings both processes back. If EverOS dies, it is PID 1 and the container stops as well.
- Browser clients: CORS preflights (`OPTIONS`) pass through to EverOS, which allows all origins by default; authenticated requests are limited to 64 MB bodies.
- `/metrics` (Prometheus) is behind the token on the public side and open on the private port.
- Memory use is roughly 200 to 300 MB at rest and around 450 MB during extraction.

## Upgrading EverOS

Bump `EVEROS_VERSION` in `Dockerfile` (upstream releases often; read its [CHANGELOG](https://github.com/EverMind-AI/EverOS/blob/main/CHANGELOG.md) for migration notes). Merging to `main` notifies everyone who deployed the template. Note breaking changes in `CHANGELOG.md`.

## License

The template files are Apache-2.0 (see `LICENSE`). EverOS itself is Apache-2.0, copyright EverMind AI; the image installs the unmodified package from PyPI.

## Files

- `Dockerfile`: EverOS from PyPI plus Caddy
- `entrypoint.sh`: token check, volume ownership, one-time init, start both processes
- `Caddyfile`: public gateway rules
- `LICENSE`: Apache-2.0 for the template files
- `TEMPLATE_OVERVIEW.md`: the marketplace description
- `CHANGELOG.md`: what changed and how to upgrade an existing deployment
