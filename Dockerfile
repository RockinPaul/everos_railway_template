FROM caddy:2 AS caddy

FROM python:3.12-slim

# EverOS from PyPI with the multimodal extra (images, PDF, audio via a vision model).
# Office documents would also need LibreOffice, which is deliberately not installed.
ARG EVEROS_VERSION=1.3.1
RUN pip install --no-cache-dir "everos[multimodal]==${EVEROS_VERSION}" \
 && groupadd --gid 1000 everos \
 && useradd --uid 1000 --gid everos --create-home --home-dir /home/everos everos

COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# EverOS reads EVEROS_<SECTION>__<KEY>. An empty API host makes uvicorn listen on IPv4 and
# IPv6 (Railway's private network); Caddy fronts the public domain on PORT with a bearer token.
ENV EVEROS_ROOT=/data \
    EVEROS_API__HOST= \
    EVEROS_API__PORT=8000 \
    EVEROS_LLM__MODEL=openai/gpt-4.1-mini \
    EVEROS_LLM__BASE_URL=https://openrouter.ai/api/v1 \
    EVEROS_MULTIMODAL__MODEL=google/gemini-3.8-flash \
    EVEROS_MULTIMODAL__BASE_URL=https://openrouter.ai/api/v1 \
    EVEROS_MULTIMODAL__FILE_URI_ALLOW_DIRS='["/data/uploads"]' \
    EVEROS_LOG_FORMAT=json \
    EVEROS_LOG_LEVEL=INFO \
    TZ=UTC \
    PORT=8080

EXPOSE 8080 8000
ENTRYPOINT ["/entrypoint.sh"]
