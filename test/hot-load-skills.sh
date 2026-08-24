#!/usr/bin/env bash
# test/hot-load-skills.sh - Skill Hot-Load Demo (G4 beat)
# Demonstrates mid-session skill attachment via TrueForge API.
# Shows that adding a git-backed SKILL.md changes the agent's available
# playbooks without restarting the server.
set -euo pipefail

TF_URL="${TF_URL:-http://localhost:8791}"
AGENT_NAME="${AGENT_NAME:-sentry-oncall}"
LOG_DIR="/tmp/sentry-hot-load-$$"
mkdir -p "$LOG_DIR"

say() { echo "[hot-load] $*"; }

cleanup() { rm -rf "$LOG_DIR"; }
trap cleanup EXIT

# --- 1. Fetch current agent config ---
say "step 1: fetch current agent manifest"
AGENT_DATA=$(curl -sf --max-time 10 "$TF_URL/api/v1/agents" \
  -H "Accept: application/json")

# Use a temp file for Python to avoid shell injection via AGENT_NAME
echo "$AGENT_DATA" > "$LOG_DIR/agents.json"
AGENT_ID=$(python3 -c "
import json, sys
with open('$LOG_DIR/agents.json') as f:
    d = json.load(f)
name = sys.argv[1]
for a in d.get('data', []):
    if a.get('name') == name:
        print(a['id']); break
" "$AGENT_NAME")

if [ -z "$AGENT_ID" ]; then
  echo "FAIL  agent '$AGENT_NAME' not found at $TF_URL"
  exit 2
fi

CURRENT_SKILLS=$(python3 -c "
import json, sys
with open('$LOG_DIR/agents.json') as f:
    d = json.load(f)
name = sys.argv[1]
for a in d.get('data', []):
    if a.get('name') == name:
        skills = a['manifest'].get('skills', [])
        print(', '.join(s['name'] for s in skills))
" "$AGENT_NAME")
say "agent $AGENT_ID skills: $CURRENT_SKILLS"

# --- 2. Check if payments-escalation is already attached ---
HAS_PAY=$(python3 -c "
import json, sys
with open('$LOG_DIR/agents.json') as f:
    d = json.load(f)
name = sys.argv[1]
for a in d.get('data', []):
    if a.get('name') == name:
        skills = [s['name'] for s in a['manifest'].get('skills', [])]
        print('yes' if 'payments-escalation' in skills else 'no')
" "$AGENT_NAME")

if [ "$HAS_PAY" = "yes" ]; then
  say "payments-escalation already attached - removing first to demo hot-load"
  python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
name = sys.argv[2]
for a in d.get('data', []):
    if a.get('name') == name:
        m = a['manifest']
        m['skills'] = [s for s in m.get('skills', []) if s['name'] != 'payments-escalation']
        print(json.dumps({'manifest': m}))
        break
" "$LOG_DIR/agents.json" "$AGENT_NAME" > "$LOG_DIR/remove.json"

  RESP=$(curl -sf -X PUT "$TF_URL/api/v1/agents/$AGENT_ID" \
    -H "Content-Type: application/json" \
    -d @"$LOG_DIR/remove.json" -w "\n%{http_code}")
  HTTP_CODE=$(echo "$RESP" | tail -1)
  if [ "$HTTP_CODE" != "200" ]; then
    echo "FAIL  removal PUT returned HTTP $HTTP_CODE"
    exit 1
  fi
  say "removed payments-escalation"
fi

# --- 3. Capture BEFORE state ---
say "step 2: capture BEFORE state"
curl -sf "$TF_URL/api/v1/agents" > "$LOG_DIR/agents-before.json"
BEFORE_SKILLS=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
name = sys.argv[2]
for a in d.get('data', []):
    if a.get('name') == name:
        skills = [s['name'] for s in a['manifest'].get('skills', [])]
        print(', '.join(skills))
" "$LOG_DIR/agents-before.json" "$AGENT_NAME")
say "BEFORE: $BEFORE_SKILLS"

# --- 4. Hot-load payments-escalation ---
say "step 3: hot-load payments-escalation via PUT"
python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
name = sys.argv[2]
for a in d.get('data', []):
    if a.get('name') == name:
        m = a['manifest']
        skills = m.setdefault('skills', [])
        existing = [s['name'] for s in skills]
        if 'payments-escalation' not in existing:
            skills.append({'name': 'payments-escalation'})
        print(json.dumps({'manifest': m}))
        break
" "$LOG_DIR/agents-before.json" "$AGENT_NAME" > "$LOG_DIR/add.json"

RESP=$(curl -sf -X PUT "$TF_URL/api/v1/agents/$AGENT_ID" \
  -H "Content-Type: application/json" \
  -d @"$LOG_DIR/add.json")

AFTER_SKILLS=$(echo "$RESP" | python3 -c "
import json, sys
d = json.load(sys.stdin)
skills = d.get('data', {}).get('manifest', {}).get('skills', [])
print(', '.join(s['name'] for s in skills))
" 2>/dev/null)

say "AFTER: $AFTER_SKILLS"

# --- 5. Verify the diff ---
say "step 4: verify hot-load"
if echo "$AFTER_SKILLS" | grep -q "payments-escalation"; then
  echo "PASS  hot-load: payments-escalation attached"
  echo "  Skill diff: [$BEFORE_SKILLS] -> [$AFTER_SKILLS]"
  echo "  payments-escalation adds: webhook-lag check, payment-method breakdown, rollback format"
else
  echo "FAIL  hot-load: payments-escalation not found after PUT"
  exit 1
fi

# --- 6. Show what changed in the agent's available playbooks ---
say "step 5: skill content diff"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ONCALL="$REPO_ROOT/agent/skills/oncall-triage/SKILL.md"
PAYMENTS="$REPO_ROOT/agent/skills/runbooks/payments-escalation/SKILL.md"

echo ""
echo "=== oncall-triage (base) ==="
grep -E "^[0-9]+\.|^##" "$ONCALL" 2>/dev/null | head -10 || echo "(file not found)"
echo ""
echo "=== payments-escalation (added) ==="
grep -E "^[0-9]+\.|^##" "$PAYMENTS" 2>/dev/null | head -10 || echo "(file not found)"
echo ""
echo "=== hot-load complete ==="
echo "The agent now has access to payment-specific checks (webhook lag, method breakdown)"
echo "that were not available in the previous session."
