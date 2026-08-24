# app/ - Victim Shop Service

## Purpose

- Minimal realistic shop service producing observable incidents for SENTRY: /orders, /payments, /checkout, Prometheus metrics at /metrics
- Chaos behavior flags (CHAOS_LATENCY_MS, CHAOS_ERROR_RATE) are the demo's deterministic failure switches

## Ownership

- `src/` - Fastify app factory, routes, metrics registry, seed fixtures
- `test/` - vitest contract tests (RED-first per docs/TDD-PROTOCOL.md)
- `Dockerfile` - multi-stage build; **build context is the repository root** so `tsconfig.base.json` can satisfy `app/tsconfig.json`'s `extends`

## Local Contracts

- `tsconfig.json` extends the repo-root base config - do NOT inline compiler options here; Docker context handling is solved in the Dockerfile, not by duplicating options
- Metrics names are contract: `checkout_latency_seconds` histogram, `http_5xx_total` counter. Latency and 5xx accounting happen in onRequest/onResponse hooks covering ALL outcomes, not inside handlers
- CHAOS_ERROR_RATE uses the instance-seeded 32-bit LCG (`Math.imul`) - keep arithmetic uint32-exact
- Port parsing tolerates junk env (falls back to 3000)

## Verification

- `pnpm --filter @sentry/app test` -> 6/6 contract tests green
- `pnpm --filter @sentry/app typecheck` -> clean
- Container rebuild from clean main must succeed on pelican

## Child DOX Index

- No child AGENTS.md files yet
