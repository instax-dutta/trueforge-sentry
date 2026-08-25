# dashboard/ - Mission Control UI

## Purpose

- Operator console for the SENTRY demo: live incident telemetry, deterministic chaos switches, and a bridge into the TrueForge chat where the agent's approval gate lives.

## Ownership

- `app/` - Next.js 15 app router: page (overview + chaos lab), api/metrics, api/chaos
- `lib/chaos.ts` - pure chaos helpers (validation, authz, MCP outcome parsing)
- `test/` - vitest unit tests for lib helpers

## Local Contracts

- Chaos actions require the `x-operator-key` header matching `OPERATOR_KEY` env; keyless when `OPERATOR_KEY` is unset (local-only deployments)
- Destructive buttons always pass a client-side confirmation modal before POSTing - the operator is the human approval for direct console actions; SENTRY agent actions go through the separate TrueForge gate
- Metrics route returns `{ok:false,error}` on any Prometheus failure; the UI must render an explicit error banner, never crash on malformed payloads
- `LAB_MCP_URL` defaults to the docker bridge (`http://172.17.0.1:8100/mcp`) since ops-MCP runs on the pelican host network; `host.docker.internal` does not resolve on Linux
- Nav URLs come from `NEXT_PUBLIC_GRAFANA_URL`, `NEXT_PUBLIC_TF_CHAT_URL`, `NEXT_PUBLIC_REPO_URL`

## Verification

- `pnpm --filter @sentry/dashboard test` -> unit tests green
- Container build succeeds from clean checkout; page renders error banner with Prometheus stopped

## Child DOX Index

- No child AGENTS.md files yet
