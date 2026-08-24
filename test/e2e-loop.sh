#!/usr/bin/env bash
# test/e2e-loop.sh - Golden Loop Acceptance Gate (G2 + G3)
# TDD RED->GREEN: inject -> SENTRY triage -> gate -> allow -> verify recovery.
# Runs from any directory; always cleans up the victim stack on exit.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

PROM_URL="${PROM_URL:-http://localhost:9090}"
TF_URL="${TF_URL:-http://localhost:8791}"
LOG_DIR="/tmp/sentry-e2e"
mkdir -p "$LOG_DIR"
SESSION_LOG="$LOG_DIR/session-$(date +%s).log"
APPROVE_LOG="$LOG_DIR/approve-$(date +%s).log"

REMOTE_HOST="${REMOTE_HOST:-tejes@pelican}"
REMOTE_DIR="${REMOTE_DIR:-~/sentry/product/infra}"

pass=0
fail=0
cleanup_done=0

cleanup() {
  if [ "$cleanup_done" -eq 0 ]; then
    echo "[e2e] cleanup: restoring baseline"
    ssh -o BatchMode=yes "$REMOTE_HOST" \
      "cd $REMOTE_DIR && CHAOS_ERROR_RATE=0 CHAOS_LATENCY_MS=0 docker compose up -d shop" >/dev/null 2>&1 || true
    cleanup_done=1
  fi
}
trap cleanup EXIT

say() { echo "[e2e] $*"; }

# Run docker compose on the remote victim host with validated numeric env only.
compose_remote() {
  local err_rate="0" lat_ms="0"
  case "${1:-}" in
    inject) err_rate="0.5" ;;
    restore|*) err_rate="0" ;;
  esac
  ssh -o BatchMode=yes "$REMOTE_HOST" \
    "cd $REMOTE_DIR && CHAOS_ERROR_RATE=$err_rate CHAOS_LATENCY_MS=$lat_ms docker compose up -d shop" >/dev/null 2>&1
}

wait_prom() { # query comparator threshold timeout_s
  bash -c 'source infra/chaos/common.sh; wait_for_prom "$1" "$2" "$3" "$4" "$5"' \
    _ "$PROM_URL" "$1" "$2" "$3" "${4:-90}"
}

# --- 0. Preflight ---
say "preflight: harness + victim stack + log dir ($LOG_DIR)"
curl -sf --max-time 10 "$TF_URL/api/v1/settings/sandbox-providers" >/dev/null || { echo "FATAL: TrueForge unreachable"; exit 2; }
curl -sf --max-time 10 "$PROM_URL/-/ready" >/dev/null || { echo "FATAL: Prometheus unreachable"; exit 2; }

# --- 1. Baseline ---
say "step 1: restore baseline"
compose_remote restore
sleep 8
if wait_prom "sum(rate(http_5xx_total[30s])) or vector(0)" "<" 0.05 60; then
  echo "PASS  baseline: 5xx <0.05"; pass=$((pass+1))
else
  echo "FAIL  baseline: still elevated"; fail=$((fail+1))
fi

# --- 2. Inject ---
say "step 2: inject bad deploy"
compose_remote inject
sleep 10
if wait_prom "sum(rate(http_5xx_total[30s]))" ">" 0.2 60; then
  echo "PASS  inject: spike detected"; pass=$((pass+1))
else
  echo "FAIL  inject: no spike within 60s"; fail=$((fail+1))
fi

# --- 3. SENTRY triage ---
say "step 3: SENTRY triage (may retry once on gateway capacity)"
SID=$(curl -sf --max-time 15 -X POST "$TF_URL/api/v1/sessions" \
  -H "Content-Type: application/json" \
  -d '{"agent":{"name":"sentry-oncall"}}' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['id'])")

GATE_TC=""
for attempt in 1 2; do
  curl -sf -N --max-time 180 -X POST "$TF_URL/api/v1/sessions/$SID/turns" \
    -H "Content-Type: application/json" \
    -d '{"input":[{"type":"user.message","content":"Investigate payment-failures alert. You MUST call these tools in order: 1) Grafana query_prometheus for sum(rate(http_5xx_total[30m])) with datasource PBFA97CFB590B2093 to get current error rate, 2) GitHub list_commits for instax-dutta/trueforge-sentry (last 10 commits) - match each commit timestamp against the spike window to identify which commit aligns with the regression onset (commit time is a proxy for deploy time), 3) State your correlation verdict (suspected culprit commit + evidence), 4) Then you MUST call sentry-lab lab_restore to propose the fix - this will trigger human approval, do NOT execute without it."}],"stream":true}' \
    > "$SESSION_LOG" 2>&1

  if grep -q "tool.approval_required" "$SESSION_LOG"; then
    GATE_TC=$(python3 -c "
import json
for line in open('$SESSION_LOG'):
    line = line.strip()
    if not line.startswith('data: '): continue
    try: d = json.loads(line[6:])
    except: continue
    if d.get('type') == 'tool.approval_required':
        print(d['tool_calls'][0]['id'])
        break")
    break
  fi

  if grep -q "503" "$SESSION_LOG" && [ "$attempt" -eq 1 ]; then
    say "WARN  attempt $attempt hit 503 capacity, retrying with fresh session"
    SID=$(curl -sf --max-time 15 -X POST "$TF_URL/api/v1/sessions" \
      -H "Content-Type: application/json" \
      -d '{"agent":{"name":"sentry-oncall"}}' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['id'])")
    continue
  fi
done

if [ -n "$GATE_TC" ]; then
  echo "PASS  triage: approval gate fired"; pass=$((pass+1))
else
  echo "FAIL  triage: no approval gate"; fail=$((fail+1))
fi

METRIC_OK=$(python3 -c "
import json, re
for line in open('$SESSION_LOG'):
    line = line.strip()
    if not line.startswith('data: '): continue
    try: d = json.loads(line[6:])
    except: continue
    if d.get('type') == 'tool.response':
        if re.search(r'\d+\.\d+', str(d.get('content',''))):
            print('yes'); break
else:
    print('no')
" 2>/dev/null || echo no)
if [ "$METRIC_OK" = "yes" ]; then
  echo "PASS  triage: metric evidence present (Prometheus decimal in tool response)"; pass=$((pass+1))
else
  echo "FAIL  triage: no metric evidence in tool responses"; fail=$((fail+1))
fi

# --- 4. Approve + verify ---
if [ -n "$GATE_TC" ]; then
  say "step 4: approve + verify recovery"
  curl -sf -N --max-time 90 -X POST "$TF_URL/api/v1/sessions/$SID/turns" \
    -H "Content-Type: application/json" \
    -d "{\"input\":[{\"type\":\"user.tool_approval\",\"thread_id\":\"main\",\"tool_call_id\":\"$GATE_TC\",\"approval\":{\"status\":\"allow\"}}],\"stream\":true}" \
    > "$APPROVE_LOG" 2>&1
  sleep 6
  if wait_prom "sum(rate(http_5xx_total[30s])) or vector(0)" "<" 0.05 90; then
    echo "PASS  recovery: back to baseline"; pass=$((pass+1))
  else
    echo "FAIL  recovery: still elevated"; fail=$((fail+1))
  fi
else
  echo "SKIP  approve: no gate TC"; fail=$((fail+1))
fi

# --- Cleanup via trap ---
cleanup_done=0
cleanup
sleep 4

echo "=== result: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
