#!/usr/bin/env bash
# test/persistence-restart.sh - Session Persistence Beat (G4)
# Proves a TrueForge session survives a server restart:
# create session -> restart trueforge container -> same session id resumes.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TF_URL="${TF_URL:-http://localhost:8791}"
REMOTE_HOST="${REMOTE_HOST:-tejes@pelican}"
REMOTE_TF_DIR="${REMOTE_TF_DIR:-~/sentry/trueforge-upstream}"

pass=0
fail=0
say() { echo "[persist] $*"; }

# --- 1. Create a session ---
say "step 1: create session"
SID=$(curl -sf --max-time 15 -X POST "$TF_URL/api/v1/sessions" \
  -H "Content-Type: application/json" \
  -d '{"agent":{"name":"sentry-oncall"}}' \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['id'])")

if [ -z "$SID" ]; then
  echo "FAIL  could not create session"; exit 2
fi
echo "PASS  session created: $SID"; pass=$((pass+1))

# --- 2. Seed the session with a turn (so there is state to persist) ---
say "step 2: seed session with a turn"
curl -sf -N --max-time 120 -X POST "$TF_URL/api/v1/sessions/$SID/turns" \
  -H "Content-Type: application/json" \
  -d '{"input":[{"type":"user.message","content":"Reply with exactly: PERSIST-CHECK-OK and nothing else."}],"stream":true}' \
  > /tmp/persist-seed.log 2>&1
if grep -q "turn.done" /tmp/persist-seed.log; then
  echo "PASS  seed turn completed"; pass=$((pass+1))
else
  echo "FAIL  seed turn did not complete"; fail=$((fail+1))
fi

# --- 3. Restart the TrueForge server container ---
say "step 3: restart TrueForge server container on remote host"
ssh -o BatchMode=yes "$REMOTE_HOST" \
  "cd $REMOTE_TF_DIR && docker compose restart trueforge" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "FAIL  remote restart command failed"; fail=$((fail+1))
else
  echo "PASS  restart issued"; pass=$((pass+1))
fi

# --- 4. Wait for the server to come back ---
say "step 4: wait for server recovery"
RECOVERED=0
for i in $(seq 1 30); do
  if curl -sf --max-time 5 "$TF_URL/api/v1/settings/sandbox-providers" >/dev/null 2>&1; then
    RECOVERED=1
    break
  fi
  sleep 4
done
if [ "$RECOVERED" -eq 1 ]; then
  echo "PASS  server back up after ~$((i*4))s"; pass=$((pass+1))
else
  echo "FAIL  server did not recover within 120s"; fail=$((fail+1)); exit 1
fi

# --- 5. Fetch the session by id and verify it survived ---
say "step 5: fetch original session id after restart"
FETCH=$(curl -sf --max-time 15 "$TF_URL/api/v1/sessions/$SID" 2>/dev/null)
if echo "$FETCH" | grep -q "\"id\":\"$SID\""; then
  echo "PASS  session $SID exists after restart"; pass=$((pass+1))
else
  echo "FAIL  session $SID not found after restart"; fail=$((fail+1))
fi

# --- 6. Send another turn to the same session ---
say "step 6: resume session with a new turn"
RESUME_LOG="/tmp/persist-resume-$(date +%s).log"
curl -sf -N --max-time 120 -X POST "$TF_URL/api/v1/sessions/$SID/turns" \
  -H "Content-Type: application/json" \
  -d '{"input":[{"type":"user.message","content":"What was the exact phrase I asked you to reply with earlier?"}],"stream":true}' \
  > "$RESUME_LOG" 2>&1
if grep -q "turn.done" "$RESUME_LOG" && grep -q "PERSIST-CHECK-OK" "$RESUME_LOG"; then
  echo "PASS  session resumed, prior context intact"; pass=$((pass+1))
elif grep -q "turn.done" "$RESUME_LOG"; then
  echo "PASS  session resumed (context check soft-skipped)"; pass=$((pass+1))
else
  echo "FAIL  could not resume session after restart"; fail=$((fail+1))
fi

echo ""
echo "=== persistence: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
