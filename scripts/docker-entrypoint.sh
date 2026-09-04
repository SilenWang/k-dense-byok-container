#!/usr/bin/env bash
# K-Dense BYOK container entrypoint
set -euo pipefail

# uv installer puts the binary here
export PATH="/root/.local/bin:${PATH}"

echo "============================================"
echo "  K-Dense BYOK — Container Entrypoint"
echo "============================================"
echo "  node: $(node --version)"
has_uv=0; command -v uv >/dev/null && has_uv=1
[ "$has_uv" = 1 ] && echo "  uv:   $(uv --version)" || echo "  uv:   NOT FOUND (agent Python tasks will fail)"

if command -v nvidia-smi &>/dev/null; then
    echo "  GPU:  $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo 'detected')"
    nvidia-smi -L 2>/dev/null | while IFS= read -r line; do echo "        $line"; done
else
    echo "  GPU:  not available (CPU-only mode)"
fi
echo ""

cd /app

# start.mjs handles: npm install → freePort → prep → spawn services → wait
# --no-browser:  we are headless, skip xdg-open
exec node start.mjs --no-browser "$@"