# DOX framework

- DOX is highly performant AGENTS.md hierarchy installed here
- Agent must follow DOX instructions across any edits

## Project Overview

- SENTRY - an on-call incident responder on TrueForge, built for The Agent Harness Hackathon (WeMakeDevs x TrueFoundry x Qodo x OpenAI), Aug 24-30 2026
- Five harness signals must be demo-visible: real MCP tools, sandbox execution, human approval gate before irreversible actions, subagent fan-out, session persistence across restart
- Wave plan and acceptance gates: see planning vault `solid-plan.md` Section D; model routing: `docs` of vault `AGENT-OPTIMIZATION.md`; test law: `docs/TDD-PROTOCOL.md`

## Binding Constraints

- Build window closes 2026-08-30 19:00 UTC. Every change lands via pull request; Qodo Merge reviews each; findings resolved by fix or reasoned rebuttal before merge; zero direct pushes to main
- TDD law per `docs/TDD-PROTOCOL.md`: failing test first for all logic, no test-after for approval gating / rollback / chaos restore paths
- Secrets: `.env` gitignored, `.env.example` placeholders only; keys and personal data never in diffs, issues, screenshots, or the demo video
- Only connect tools/data/accounts we own (local chaos-lab stack, our GitHub repos, our gateway)
- No emojis; dashes not em dashes
- Destructive MCP tools stay gated via `require_approval_for_tools: ["@destructive"]` - never bypass in code, skills, or prompts

## User Preferences

- Reproduce bugs end-to-end as a user would before unit tests
- Do not weight development cost heavily; AI can build faster than estimated
- Batch/long jobs run on pelican (`ssh tejes@pelican`, workdir `/home/tejes/sentry`), local Mac is dev seat only
- Never touch pelican neighbors: pterodactyl containers (9000-9008), host pg 5432 / redis 6379 / mariadb 3306 / ollama 11434, ports 80/443, cloudflared

## Core Contract

- AGENTS.md files are binding work contracts for their subtrees
- Work products, source materials, instructions, records, assets, and durable docs must stay understandable from the nearest applicable AGENTS.md plus every parent AGENTS.md above it

## Read Before Editing

1. Read the root AGENTS.md
2. Identify every file or folder you expect to touch
3. Walk from the repository root to each target path
4. Read every AGENTS.md found along each route
5. If a parent AGENTS.md lists a child AGENTS.md whose scope contains the path, read that child and continue from there
6. Use the nearest AGENTS.md as the local contract and parent docs for repo-wide rules
7. If docs conflict, the closer doc controls local work details, but no child doc may weaken DOX

Do not rely on memory. Re-read the applicable DOX chain in the current session before editing.

## Update After Editing

Every meaningful change requires a DOX pass before the task is done.

Update the closest owning AGENTS.md when a change affects:

- purpose, scope, ownership, or responsibilities
- durable structure, contracts, workflows, or operating rules
- required inputs, outputs, permissions, constraints, side effects, or artifacts
- user preferences about behavior, communication, process, organization, or quality
- AGENTS.md creation, deletion, move, rename, or index contents

Update parent docs when parent-level structure, ownership, workflow, or child index changes. Update child docs when parent changes alter local rules. Remove stale or contradictory text immediately.

## Hierarchy

- Root AGENTS.md is the DOX rail: project-wide instructions, global preferences, durable workflow rules, and the top-level Child DOX Index
- Child AGENTS.md files own domain-specific instructions and their own Child DOX Index
- The closer a doc is to the work, the more specific and practical it must be

## Child Doc Shape

Default section order:
- Purpose
- Ownership
- Local Contracts
- Work Guidance
- Verification
- Child DOX Index

## Style

- Keep docs concise, current, and operational
- Document stable contracts, not diary entries
- Prefer direct bullets with explicit names
- Delete stale notes instead of explaining history

## Closeout

1. Re-check changed paths against the DOX chain
2. Update nearest owning docs and any affected parents or children
3. Refresh every affected Child DOX Index
4. Run existing verification when relevant
5. Report any docs intentionally left unchanged and why

## Child DOX Index

- `app/` - victim shop service SENTRY watches (routes, Prometheus instrumentation, CHAOS_* behavior flags)
- `infra/` - docker compose victim stack, Prometheus/Grafana provisioning, chaos injection scripts
- `agent/` - TrueForge agent manifest and git-backed SKILL.md playbooks
- `dashboard/` - mission control UI embedding trueforge-ui, chaos-lab controls, RCA view
- `sdk-hooks/` - stretch: Alertmanager webhook service opening TrueForge sessions via SDK
- `docs/` - TDD protocol, ADRs, ai-disclosure
- Root-owned files: README.md, LICENSE, .env.example, package.json, pnpm-workspace.yaml, tsconfig.base.json
