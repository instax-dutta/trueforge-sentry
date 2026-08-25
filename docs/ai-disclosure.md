# AI Disclosure

This project was built with AI coding assistance, disclosed per hackathon rules 11-13. Every decision was reviewed by the human team, and the team can explain and defend each technical choice.

## What AI assisted

| Area | Tool | Nature of assistance |
|---|---|---|
| Code implementation | Codebuff (Buffy agent) | Writing TypeScript for the shop service, bash test scripts, SKILL.md playbooks, ADR drafts |
| PR review | Qodo Merge (GitHub app) | Automated code review on every pull request; findings resolved in-thread before merge |
| Documentation | Codebuff | Drafting README, ADRs, this disclosure; human edited and approved final content |

## How we verified

- Every PR passed automated Qodo review with findings addressed or rebutted in-thread (11 PRs, trail public on GitHub)
- The golden-loop e2e test (`test/e2e-loop.sh`) exercises the real stack end to end: chaos injection over SSH, TrueForge API sessions, Prometheus assertions, approval gate event, recovery verification
- The hot-load demo script (`test/hot-load-skills.sh`) runs against the live agent manifest and asserts the skill diff
- Chaos spec (`infra/chaos/chaos.spec.sh`) verifies inject-then-restore round trips against live Prometheus

## Human decisions

The team made all architectural decisions and can explain each:

- Hosted TrueForge mode for Postgres-backed session persistence (ADR 001)
- Compose-tag rollback via custom sentry-lab MCP instead of a kubernetes cluster (ADR 002)
- Model tiers selected by live tool-calling probes on a free gateway (ADR 003)
- Approval gating scoped to destructive tools only; read-only triage autonomous
- Skills as git-backed SKILL.md playbooks rather than prompt paste

No keys, tokens, or personal data appear in commits, issues, screenshots, or the demo video. `.env` is gitignored; `.env.example` carries placeholders only.
