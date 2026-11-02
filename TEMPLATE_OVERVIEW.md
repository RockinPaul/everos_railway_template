# Deploy and Host EverOS on Railway

EverOS is an open-source memory layer for AI agents: it turns conversations into durable, user-owned Markdown memories with a local index, and serves them back to any agent through an HTTP API. It powers the memory plugins for OpenClaw, Hermes, DeepSeek Harness and Dify. This template deploys EverOS 1.5.1 with the multimodal extra as a single Railway service with a persistent volume and a token-protected public API.

## About Hosting EverOS

Hosting EverOS on Railway means one container running two processes: EverOS itself and a small Caddy gateway. EverOS ships no authentication and expects a trusted caller, so the gateway requires a bearer token, generated at deploy time, on the public domain; only the health endpoint stays open. On Railway's private network the same instance is reachable without a token, which is what the official plugins expect. Memories, the SQLite state and the LanceDB indexes live on one volume. You bring one LLM key (OpenRouter by default, any OpenAI-compatible endpoint works); embedding and rerank providers are optional upgrades that unlock vector and hybrid search.

## Common Use Cases

- Shared long-term memory for several agents and tools, each keeping its own scope through `app_id` and `project_id`
- A memory backend for OpenClaw, Hermes or DeepSeek Harness deployed in the same Railway project
- Extracting user profiles, episodes and facts from chat transcripts and searching them from your own application

## Dependencies for EverOS Hosting

- A Railway account (about 300 MB of memory at rest)
- An OpenRouter key, or any OpenAI-compatible chat model endpoint
- Optional: an OpenAI-compatible embedding endpoint for vector search, a rerank endpoint

### Deployment Dependencies

- EverOS upstream repository: https://github.com/EverMind-AI/EverOS
- EverOS API reference: https://github.com/EverMind-AI/EverOS/blob/v1.5.1/docs/api.md
- Official plugins: https://github.com/EverMind-AI/plugins
- Template repository: https://github.com/RockinPaul/everos_railway_template

### Implementation Details

- `everos`: `python:3.12-slim` with `everos[multimodal]==1.5.1` from PyPI and the Caddy binary from `caddy:2`. Caddy on `PORT` (public domain) enforces `Authorization: Bearer ${API_TOKEN}` for everything except `/health`; EverOS listens on `:8000` for the private network. Volume at `/data`, healthcheck `/health`, unprivileged user.
- Variables: `API_TOKEN` (generated), `EVEROS_LLM__API_KEY` (yours), model and base URL defaults for OpenRouter, optional embedding, rerank and multimodal settings, JSON logs.
- Office documents need LibreOffice, which is not included; images, PDFs and audio work through the multimodal model.

First steps: read `API_TOKEN` from the service variables, call `/health`, then `POST /api/v2/memory/add`, `/flush` and `/search` with the token. Plugins inside the project use `http://everos.railway.internal:8000`.

## Why Deploy EverOS on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying EverOS on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
