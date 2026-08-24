#!/usr/bin/env bash
# chaos.spec.sh - executable acceptance spec for the chaos loop (T6).
# RED until infra/docker-compose.yml + chaos scripts make it pass.
# Usage: PROM_URL=http://localhost:9090 bash chaos.spec.sh
set -euo pipefail

PROM_URL="${PROM_URL:-http://localhost:9090}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=chaos/common.sh
source "$SCRIPT_DIR/chaos/common.sh"

pass=0; fail=0
check() { # name expr comparator threshold
  local name="$1" expr="$2" cmp="$3" thr="$4"
  if wait_for_prom "$PROM_URL" "$expr" "$cmp" "$thr" 90; then
    echo "PASS  $name"; pass=$((pass+1))
  else
    echo "FAIL  $name"; fail=$((fail+1))
  fi
}

echo "== chaos spec against $PROM_URL =="

prom_up=$(curl -s -o /dev/null -w '%{http_code}' "$PROM_URL/-/ready" || true)
if [ "$prom_up" != "200" ]; then
  echo "FATAL Prometheus not ready at $PROM_URL"; exit 2
fi

# 1. healthy baseline: no 5xx flowing
"$SCRIPT_DIR/chaos/restore.sh" >/dev/null
check "baseline: 5xx rate near zero" 'sum(rate(http_5xx_total[30s])) or vector(0)' '<' 0.05

# 2. bad deploy spikes errors
"$SCRIPT_DIR/chaos/inject-bad-deploy.sh" >/dev/null
check "after inject: 5xx rate > 0.2/s" 'sum(rate(http_5xx_total[30s]))' '>' 0.2

# 3. restore returns to baseline
"$SCRIPT_DIR/chaos/restore.sh" >/dev/null
check "after restore: 5xx back near zero" 'sum(rate(http_5xx_total[30s])) or vector(0)' '<' 0.05

echo "== result: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
