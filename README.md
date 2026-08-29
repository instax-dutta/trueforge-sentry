# SENTRY - On-Call Incident Responder on TrueForge

> An AI agent that investigates production incidents, correlates cause, and stops at a human approval gate before rollback. Built for [The Agent Harness Hackathon](https://www.wemakedevs.org/hackathons/trueforge) on [TrueForge](https://trueforge.dev).

**The problem:** Chatbots answer questions. Agents act on infrastructure. Acting requires tools, a sandbox, and a control layer that stops before something destructive happens.

**The solution:** SENTRY triages over MCP (Grafana + GitHub), correlates in a Daytona sandbox, holds at a human Allow/Deny gate, verifies recovery, and files an RCA.

## Architecture

```
Alert (Grafana) -> TrueForge session -> sentry-oncall agent
  |-- MCP: grafana connector   -> Prometheus queries (read-only, autonomous)
  |-- MCP: github connector    -> deploy history correlation (read-only)
  |-- Subagents                -> parallel triage (metrics scout / log analyst)
  |-- Daytona sandbox          -> bisect + aggregation code (Code Mode)
  |-- APPROVAL GATE            -> sentry-lab MCP destructive tools pause here
  +-- Post-recovery            -> verification query + GitHub RCA issue
```

## Quickstart

### Prerequisites

- Docker and Docker Compose
- TrueForge server (self-hosted or cloud)
- SSH access to the infrastructure host

### 1. Start the victim stack

```bash
cd infra
docker compose up -d
```

This starts:
- **Shop service** (Fastify + prom-client) on port 3000
- **Traffic generator** (~4 req/s synthetic load)
- **Prometheus** on port 9090
- **Grafana** on port 3001

### 2. Register the agent

```bash
# Create the agent with the manifest
curl -X POST http://localhost:8791/api/v1/agents \
  -H "Content-Type: application/json" \
  -d '{
    "name": "sentry-oncall",
    "manifest": {
      "model": {"name": "aeglyn-gateway/hy3-free"},
      "instructions": "You are SENTRY, an on-call incident responder...",
      "mcp_servers": [
        {"name": "grafana", "preload": true},
        {"name": "github", "preload": true},
        {"name": "sentry-lab", "require_approval_for_tools": ["lab_inject_bad_deploy", "lab_restore"]}
      ],
      "skills": ["oncall-triage", "payments-escalation"]
    }
  }'
```

### 3. Inject chaos and watch

```bash
# Inject chaos (50% error rate)
CHAOS_ERROR_RATE=0.5 docker compose up -d --force-recreate --no-deps shop

# Open TrueForge UI and send:
# "There are payment failures on production. Investigate and roll back."
```

### 4. Restore baseline

```bash
CHAOS_ERROR_RATE=0 docker compose up -d --force-recreate --no-deps shop
```

## How It Works

### The Investigation Sequence

1. **Query Prometheus** - SENTRY reads the 5xx error rate over MCP (Grafana connector)
2. **List GitHub commits** - Correlates the spike with recent deploys
3. **Call lab_restore** - Proposes rollback, triggers the approval gate
4. **Human approves** - Allow/Deny card appears in TrueForge UI
5. **Rollback executes** - Chaos is restored, 5xx drops to zero
6. **Verify recovery** - Confirms error rate is back to baseline

### The Approval Gate (The Leash)

The whole point of SENTRY is that it *cannot act without a human*. The harness enforces this through configuration, not prompts:

```json
"require_approval_for_tools": ["lab_inject_bad_deploy", "lab_restore"]
```

Any tool listed here pauses the turn and emits a `tool.approval_required` event. The agent stops, a card appears, and nothing happens until a human clicks Allow or Deny.

### Skills as Git-Backed Playbooks

Skills are just `SKILL.md` files in the repo, registered via the API and loaded progressively. They carry the licence language:

```markdown
7. STOP. Do not call any write/destructive tool. Recommend the action
   and wait for human approval.
```

Two skills:
- **oncall-triage** - Base triage playbook (10 steps)
- **payments-escalation** - Payment-specific extension (5 steps)

## What TrueForge Handles

| Capability | TrueForge | SENTRY |
|---|---|---|
| Execution loop | Yes | - |
| Streaming | Yes | - |
| Tool routing | Yes | - |
| Approval gate | Yes (config-driven) | Manifest config |
| MCP connectors | Yes | 3 registered |
| Subagent orchestration | Yes | Named fan-out |
| Session persistence | Yes (Postgres) | - |
| Sandbox (Daytona) | Yes | On-demand |
| Generative UI | Yes | RCA chart cards |
| Context compaction | Yes | - |
| Incident response logic | - | Yes |
| Chaos lab | - | Yes |
| Victim service | - | Yes |
| SKILL.md playbooks | - | Yes |

## Model Selection

Tested 5 models end-to-end (chaos inject -> investigation -> approval gate -> rollback -> recovery):

| Model | E2E Time | Approval Gate | Status |
|---|---|---|---|
| **hy3-free** | **36.8s** | **PASS** | **Flagship** |
| nemotron-3-ultra-free | 24.8s | PASS | Fallback |
| minimax-m3 | n/a | 75% deviation | ELIMINATED |
| best-free | 206.5s | Never fires | ELIMINATED |

**hy3-free** at 2.8s per tool call completes the full investigation in 36.8s - under the 40s demo budget. The fastest model (minimax at 0.5s) skips the approval gate 75% of the time, making it useless for the demo.

## Testing

### E2E Golden Loop

```bash
# Run the full test suite
TF_URL=http://localhost:8791 REMOTE_HOST=tejes@pelican \
  REMOTE_DIR='~/sentry/product/infra' \
  bash test/e2e-loop.sh
```

### Hot-Load Skills Demo

```bash
TF_URL=http://localhost:8791 bash test/hot-load-skills.sh
```

### Session Persistence

```bash
TF_URL=http://localhost:8791 REMOTE_HOST=tejes@pelican \
  bash test/persistence-restart.sh
```

## Project Structure

```
trueforge-sentry/
  agent/
    skills/
      oncall-triage/SKILL.md              Base triage playbook
      runbooks/payments-escalation/       Payment-specific extension
  app/
    src/
      server.ts                           Fastify shop service
      metrics.ts                          prom-client instrumentation
  infra/
    docker-compose.yml                    Shop + traffic-gen + Prometheus + Grafana
    grafana/                              Dashboards and provisioning
    chaos/                                Chaos injection scripts
  test/
    e2e-loop.sh                           Golden-loop acceptance gate
    hot-load-skills.sh                    Skill hot-load demo
    e2e-model-test.py                     Model comparison test
  docs/
    adr/                                  Architecture Decision Records
    ai-disclosure.md                      AI usage disclosure
    AGENT-OPTIMIZATION.md                 Model performance benchmarks
  README.md                               This file
```

## Links

- **Blog post:** [We gave an AI agent a licence to act - and built the leash](https://blog.sdad.pro/blog/sentry-licence-to-act)
- **Demo video:** *(record and add link here before submission)*
- **Hackathon:** [The Agent Harness Hackathon](https://www.wemakedevs.org/hackathons/trueforge)
- **TrueForge:** [trueforge.dev](https://trueforge.dev) | [GitHub](https://github.com/truefoundry/trueforge)

## Tags

#ai-agents #mcp #opensource #sre #hackathon

---

*Disclosure: most of the code in this project was written by AI coding agents under my direction, reviewed by Qodo on every one of the 14 merged pull requests, and verified against live infrastructure before it counted.*

*The Agent Harness Hackathon is organised by WeMakeDevs with TrueFoundry and Qodo. SENTRY is not affiliated with any spy franchise, whatever the codename suggests.*
