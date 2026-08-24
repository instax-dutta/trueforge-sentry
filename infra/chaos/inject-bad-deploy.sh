#!/usr/bin/env bash
# Failure mode A: bad deploy -> deterministic ~50% checkout 503s.
# Works locally (compose env file) and on pelican (~/sentry/product/infra).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if command -v docker >/dev/null && docker compose ls 2>/dev/null | grep -q sentry; then
  cd "$DIR"
  CHAOS_ERROR_RATE=0.5 CHAOS_LATENCY_MS=0 docker compose up -d shop
else
  echo "hint: run on host with the sentry compose project, or set SHOP_ENV_FILE"
  exit 1
fi
echo "bad deploy injected: CHAOS_ERROR_RATE=0.5"
