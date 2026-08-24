#!/usr/bin/env bash
# test/hot-load-skills.sh - Skill Hot-Load Demo (G4 beat)
# Demonstrates mid-session skill attachment via TrueForge API.
# Shows that adding a git-backed SKILL.md changes the agent's available
# playbooks without restarting the server.
set -uo pipefail

TF_URL="${TF_URL:-http://localhost:8791}"
AGENT_NAME="${AGENT_NAME:-sentry-oncall}"

say() { echo "[hot-load] $*"; }

# --- 1. Fetch current agent config ---
say "step 1: fetch current agent manifest"
AGENT_DATA=$(curl -sf --max-time 10 "$TF_URL/api/v1/agents" \
  -H "Accept: application/json")
AGENT_ID=$(echo "$AGENT_DATA" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for a in d.get('data', []):
    if a.get('name') == '$AGENT_NAME':
        print(a['id']); break
")
CURRENT_SKILLS=$(echo "$AGENT_DATA" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for a in d.get('data', []):
    if a.get('name') == '$AGENT_NAME':
        skills = a['manifest'].get('skills', [])
        print(', '.join(s['name'] for s in skills))
")
say "agent $AGENT_ID skills: $CURRENT_SKILLS"

# --- 2. Check if payments-escalation is already attached ---
HAS_PAY=$(echo "$AGENT_DATA" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for a in d.get('data', []):
    if a.get('name') == '$AGENT_NAME':
        skills = [s['name'] for s in a['manifest'].get('skills', [])]
        print('yes' if 'payments-escalation' in skills else 'no')
")

if [ "$HAS_PAY" = "yes" ]; then
  say "payments-escalation already attached - removing first to demo hot-load"
  # Remove payments-escalation
  curl -sf http://localhost:8791/api/v1/agents 2>&1 | python3 -c "
import json, sys
d = json.load(sys.stdin)
for a in d.get('data', []):
    if a.get('name') == '$AGENT_NAME':
        m = a['manifest']
        m['skills'] = [s for s in m.get('skills', []) if s['name'] != 'payments-escalation']
        print(json.dumps({'manifest': m}))
" > /tmp/agent-update.json
  curl -sf -X PUT "$TF_URL/api/v1/agents/$AGENT_ID" \
    -H "Content-Type: application/json" \
    -d @/tmp/agent-update.json >/dev/null
  say "removed payments-escalation"
fi

# --- 3. Capture BEFORE state ---
say "step 2: capture BEFORE state"
BEFORE_SKILLS=$(curl -sf "$TF_URL/api/v1/agents" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for a in d.get('data', []):
    if a.get('name') == '$AGENT_NAME':
        skills = [s['name'] for s in a['manifest'].get('skills', [])]
        print(', '.join(skills))
")
say "BEFORE: $BEFORE_SKILLS"

# --- 4. Hot-load payments-escalation ---
say "step 3: hot-load payments-escalation via PUT"
curl -sf "$TF_URL/api/v1/agents" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for a in d.get('data', []):
    if a.get('name') == '$AGENT_NAME':
        m = a['manifest']
        existing = [s['name'] for s in m.get('skills', [])]
        if 'payments-escalation' not in existing:
            m['skills'].append({'name': 'payments-escalation'})
        print(json.dumps({'manifest': m}))
" > /tmp/agent-update.json

RESP=$(curl -sf -X PUT "$TF_URL/api/v1/agents/$AGENT_ID" \
  -H "Content-Type: application/json" \
  -d @/tmp/agent-update.json)

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
ONCALL=$(curl -sf "https://raw.githubusercontent.com/instax-dutta/trueforge-sentry/main/agent/skills/oncall-triage/SKILL.md" 2>/dev/null || echo "(fetch failed)")
PAYMENTS=$(curl -sf "https://raw.githubusercontent.com/instax-dutta/trueforge-sentry/main/agent/skills/runbooks/payments-escalation/SKILL.md" 2>/dev/null || echo "(fetch failed)")

echo ""
echo "=== oncall-triage (base) ==="
echo "$ONCALL" | grep -E "^\d+\.|^##" | head -10
echo ""
echo "=== payments-escalation (added) ==="
echo "$PAYMENTS" | grep -E "^\d+\.|^##" | head -10
echo ""
echo "=== hot-load complete ==="
echo "The agent now has access to payment-specific checks (webhook lag, method breakdown)"
echo "that were not available in the previous session."
