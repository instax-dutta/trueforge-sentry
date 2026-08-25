# agent/ - TrueForge Agent Definition

## Purpose

- Owns the TrueForge agent definition: the saved `sentry-oncall` manifest (model, connectors, skills, approval policy) and the git-backed playbooks that drive investigations.

## Ownership

- `skills/oncall-triage/SKILL.md` - base read-only triage playbook
- `skills/runbooks/payments-escalation/SKILL.md` - payment-specific escalation extension
- The live agent manifest is stored in TrueForge via API (`PUT /api/v1/agents`) - this directory holds only the git-backed skills; keep a manifest snapshot aligned when instructions change

## Local Contracts

- **Spike onset is data-driven**: regression onset = first timestamp where `sum(rate(http_5xx_total[5m]))` crosses 2x the pre-incident baseline, computed via range query + sandbox code. Commit matching uses [onset minus 10m, onset plus 2m]. Never guess onset from a single smoothed rate.
- **Verdict evidence contract**: every verdict reports error rate BEFORE (onset-10m) and AFTER (onset+10m), latency delta, culprit commit SHA + timestamp type (commit vs deploy time), and confidence.
- Read-only tools run autonomously; any destructive proposal ends with an explicit approval request (TrueForge gate fires on sentry-lab destructive tools).
- All aggregation math runs as sandbox code; numbers are quoted exactly as tools return them.

## Work Guidance

- When changing playbook steps, mirror the change in `test/e2e-loop.sh` triage prompt so the acceptance gate stays aligned with the contract.

## Verification

- Skills register via `POST /api/v1/settings/skills` against this repo path without error
- e2e golden loop (`test/e2e-loop.sh`) passes 5/5 steps on the live stack

## Child DOX Index

- No child AGENTS.md files yet
