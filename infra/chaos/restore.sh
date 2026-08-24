#!/usr/bin/env bash
# Restore healthy baseline: clear all chaos flags.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if command -v docker >/dev/null && docker compose ls 2>/dev/null | grep -q sentry; then
  cd "$DIR"
  CHAOS_ERROR_RATE=0 CHAOS_LATENCY_MS=0 docker compose up -d shop
else
  echo "hint: run on host with the sentry compose project"
  exit 1
fi
echo "restored: chaos flags cleared"
