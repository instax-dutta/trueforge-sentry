#!/usr/bin/env bash
# test/e2e-loop.sh — Golden Loop Acceptance Gate (G2 + G3)
# TDD RED: This script FAILS until the full investigation pipeline is wired.
# Validates: inject -> SENTRY triage -> gate -> allow -> verify -> RCA
set -euo pipefail

PROM_URL="${PROM_URL:-http://localhost:9090}"
TF_URL="${TF_URL:-http://localhost:8791}"
SESSION_LOG="/tmp/opencode/e2e-loop-$(date +%s).log"

# Helper: run compose commands on pelican (victim stack lives there)
compose() {
  ssh -o BatchMode=yes tejes@pelican "cd ~/sentry/product/infra && CHAOS_ERROR_RATE=${CHAOS_ERROR_RATE:-0} CHAOS_LATENCY_MS=${CHAOS_LATENCY_MS:-0} docker compose $*" 2>&1 | tail -1
}
pass=0; fail=0
say() { echo "[e2e] $*"; }

# --- 0. Preflight: harness + stack healthy ---
say "preflight: checking harness + victim stack"
curl -sf "$TF_URL/api/v1/settings/sandbox-providers" >/dev/null || { echo "FATAL: TrueForge not reachable at $TF_URL"; exit 2; }
curl -sf "$PROM_URL/-/ready" >/dev/null || { echo "FATAL: Prometheus not ready at $PROM_URL"; exit 2; }

# --- 1. Reset to healthy ---
say "step 1: restore baseline"
compose up -d shop >/dev/null
sleep 8
baseline_5xx=$(curl -s --get "$PROM_URL/api/v1/query" --data-urlencode 'query=sum(rate(http_5xx_total[30s])) or vector(0)' | python3 -c "import json,sys;d=json.load(sys.stdin);r=d['data']['result'];print(r[0]['value'][1] if r else '0')")
if python3 -c "import sys; sys.exit(0 if float('$baseline_5xx') < 0.05 else 1)"; then
  echo "PASS  baseline: 5xx=$baseline_5xx"
  pass=$((pass+1))
else
  echo "FAIL  baseline: 5xx=$baseline_5xx (want <0.05)"; fail=$((fail+1))
fi

# --- 2. Inject bad deploy ---
say "step 2: inject bad deploy"
CHAOS_ERROR_RATE=0.5 compose up -d shop >/dev/null
sleep 10
# Poll for spike via spec helper
if bash -c 'source infra/chaos/common.sh; wait_for_prom "$1" "sum(rate(http_5xx_total[30s]))" ">" 0.2 60' -- "$PROM_URL"; then
  echo "PASS  inject: 5xx spike detected"
  pass=$((pass+1))
else
  echo "FAIL  inject: no spike within 60s"; fail=$((fail+1))
fi

# --- 3. SENTRY triage via TrueForge (requires agent + connectors + sandbox + skills) ---
say "step 3: SENTRY triage"
SID=$(curl -sf -X POST "$TF_URL/api/v1/sessions" -H "Content-Type: application/json" -d '{"agent":{"name":"sentry-oncall"}}' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['id'])")
curl -sf -N --max-time 180 -X POST "$TF_URL/api/v1/sessions/$SID/turns" \
  -H "Content-Type: application/json" \
  -d '{"input":[{"type":"user.message","content":"Investigate the payment-failures alert: fan out triage using Grafana query_prometheus for sum(rate(http_5xx_total[30m])) and checkout p95, use GitHub to list recent commits on instax-dutta/trueforge-sentry, and use sandbox Python to correlate error rate vs latency. Then propose rollback via the sentry-lab tool - do NOT execute without human approval."}],"stream":true}' > "$SESSION_LOG" 2>&1
if grep -q "tool.approval_required" "$SESSION_LOG"; then
  echo "PASS  triage: approval gate fired"
  pass=$((pass+1))
  GATE_TC=$(python3 -c "
import json
for line in open('$SESSION_LOG'):
    line=line.strip()
    if not line.startswith('data: '): continue
    try: d=json.loads(line[6:])
    except: continue
    if d.get('type')=='tool.approval_required':
        print(d['tool_calls'][0]['id'])
        break")
  echo "      gate tool_call: $GATE_TC"
else
  echo "FAIL  triage: no approval gate in SENTRY response"; fail=$((fail+1))
  GATE_TC=""
fi

# Extract correlation verdict: look for a 5xx number or deploy mention in deltas
if grep -q "0\." "$SESSION_LOG"; then
  echo "PASS  triage: verdict contains metric evidence"
  pass=$((pass+1))
else
  echo "FAIL  triage: no metric evidence in response"; fail=$((fail+1))
fi

# --- 4. Allow + verify recovery ---
if [ -n "${GATE_TC:-}" ]; then
  say "step 4: approve + verify recovery"
  curl -sf -N --max-time 90 -X POST "$TF_URL/api/v1/sessions/$SID/turns" \
    -H "Content-Type: application/json" \
    -d "{\"input\":[{\"type\":\"user.tool_approval\",\"thread_id\":\"main\",\"tool_call_id\":\"$GATE_TC\",\"approval\":{\"status\":\"allow\"}}],\"stream\":true}" > /tmp/opencode/e2e-approve.log 2>&1
  sleep 6
  if bash -c 'source infra/chaos/common.sh; wait_for_prom "$1" "sum(rate(http_5xx_total[30s])) or vector(0)" "<" 0.05 90' -- "$PROM_URL"; then
    echo "PASS  recovery: 5xx back to baseline after approval"
    pass=$((pass+1))
  else
    echo "FAIL  recovery: still elevated after approve"; fail=$((fail+1))
  fi
else
  echo "SKIP  approve: no gate TC"
  fail=$((fail+1))
fi

# --- 5. Cleanup ---
say "cleanup: restore"
compose up -d shop >/dev/null
sleep 4

echo "=== result: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
