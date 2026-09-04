# syntax=docker/dockerfile:1
#
# K-Dense BYOK container
# Build:  docker compose build
#        (or: docker build -t k-dense-byok:local .)
#
# GPU support: requires NVIDIA Container Toolkit + Docker >= 25.
#   docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d

FROM node:22-bookworm-slim AS base

ENV DEBIAN_FRONTEND=noninteractive \
    NODE_ENV=development \
    NEXT_TELEMETRY_DISABLED=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# -- system dependencies --------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    lsof \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# -- uv (Python package manager used by the agent sandbox) ----------
# If this step fails (SSL/SYSCALL on some networks), uv can also be
# installed at runtime; the app still boots without it.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh || echo "[WARN] uv install skipped"

WORKDIR /app

# -- clone the BYOK source at a pinned version ----------------------
ARG BYOK_REPO=https://github.com/K-Dense-AI/k-dense-byok.git
ARG BYOK_REF=main
RUN git clone --depth 1 --branch ${BYOK_REF} ${BYOK_REPO} /app && \
    rm -rf .git

# Pre-seed a minimal .env so start.mjs does NOT copy .env.example
# (which would clobber the environment passed by docker compose).
RUN touch .env

# -- npm install ----------------------------------------------------
# server/ & web/ each have package-lock.json; npm ci is reproducible.
RUN cd server && npm ci --no-audit --no-fund --loglevel=error
RUN cd web    && npm ci --no-audit --no-fund --loglevel=error

# -- Chromium for pi-web-access (browser automation) ----------------
RUN cd server && npx playwright install --with-deps chromium

# -- entrypoint -----------------------------------------------------
COPY scripts/ /scripts/
RUN cp /scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh && rm -rf /scripts

EXPOSE 3000 8000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]