# TDD Protocol — binding from first commit

> Established Aug 24 pre-window by TDD orchestrator mandate. This file defines the red-green-refactor contract every wave task inherits. It is a planning artifact; it moves into the product repo at bootstrap (PR #1) and lives under `docs/`.

## 1. The law

1. **Red first:** no production code lands without a failing test that names the behavior. The test is written before the fix, committed in the same PR (test file may precede impl within the PR's commits).
2. **Green minimally:** implement the smallest change that passes. No speculative abstractions.
3. **Refactor with suite green:** rename/extract only when the full suite passes; suite rerun required after refactor commits.
4. **Merge gate:** PR cannot merge with any failing test, any skipped test lacking an linked issue, or unresolved Qodo findings. Qodo review is part of the green phase.
5. **No test-after for safety-critical logic:** approval gating, rollback execution, and chaos restore paths are forbidden from test-after development entirely.

## 2. Test pyramid for SENTRY

| Level | Scope | Runner | Target |
|---|---|---|---|
| Unit | shop route handlers, metrics registry, manifest schema validation, skill frontmatter lint | vitest | fast (<10s total), >70% line coverage on `app/src` logic (victim stack stays lean - over-testing a fixture is waste) |
| Contract | /metrics output shape vs Prometheus scrape expectations; Grafana dashboard JSON provisionable; agent.json vs TrueForge spec schema | vitest + zod schemas recorded from real payloads | fixtures captured from live scrapes, never hand-invented |
| E2E golden loop | inject -> spike visible -> investigate -> hold -> allow -> rollback -> recovery visible -> RCA issue | `test/e2e-loop.sh` (bash + curl + promctl jq asserts) | one command, exit 0; wall-clock < 90s |
| Stress | golden loop x5 unattended | same script, loop=5 | 5/5 pass = Gate G5 |

## 3. Red-green map per wave task

| Task | Failing test written first | Green implementation | Refactor hook |
|---|---|---|---|
| T4 shop service | `shop.routes.test.ts`: GET /orders returns seed rows; GET /metrics exposes `checkout_latency_seconds` histogram + `http_5xx_total` counter; setting `CHAOS_LATENCY_MS=2000` raises observed p50 in scrape; `CHAOS_ERROR_RATE=0.5` flips half responses 5xx | Fastify routes + prom-client registry reading env flags | extract metric naming to constants module |
| T6 chaos scripts | `chaos.spec.sh`: after inject-bad-deploy, PromQL `rate(http_5xx_total[1m])` > baseline x2 within 60s; after restore, within 5% of baseline within 60s | inject/restore scripts (kubectl set image OR compose tag swap) | shared prom_wait helper extracted once second script needs it |
| T3/T9 agent manifest | `manifest.schema.test.ts`: agent.json parses against zod mirror of TrueForge spec; kubernetes server entry has non-empty `require_approval_for_tools`; every `skills[]` name maps to existing SKILL.md file; model FQN matches provider configured in `.env` | the manifest itself + tiny loader | schema module reused by sdk-hooks validation |
| T11 Generative UI beat | covered by golden-loop assertion: session transcript contains a generative-ui block after recovery step | prompt/instruction tuning in manifest | n/a |
| T15 sdk-hooks (stretch) | `webhook.contract.test.ts`: POST Alertmanager payload -> expects call to POST {TF_URL}/api/v1/sessions with agent sentry-oncall and alert text embedded; unauthorized request rejected 401 | Fastify receiver w/ bearer check | payload mapper isolated for reuse |
| Golden loop (G3) | the loop script IS the spec: each stage asserts observable state (metric delta, approval card pending state via API, post-allow verification query, GitHub issue exists) | wiring across components | assertions parameterized by config for stress mode |

## 4. Fixtures and doubles

- Record real Prometheus scrape JSON and real Grafana panel queries into `test/fixtures/` on Day 1 (after stack is up). Tests assert against these shapes - never invent metric names twice differently.
- TrueForge API is NOT mocked in golden loop (real server required). Only sdk-hooks unit tests mock it.
- No snapshot testing of model outputs - nondeterministic by design. Assert structure (tool called, args parse, verdict field present), not prose.

## 5. Anti-patterns explicitly banned

- Writing implementation then backfilling tests to pass review (test-after) for anything in section 3.
- Sleep-based flaky waits in e2e (poll with timeout instead).
- Mocking Prometheus response shapes inline per-test (single fixture source of truth).
- Marking tests skip without a tracking issue reference in the same line.
- Testing the chat UI pixel-level (out of scope; Savile Row evidence is the video + graceful-degradation manual check).

## 6. Metrics reviewed daily at standup

Gate pass rate, golden-loop wall-clock trend, coverage on app/src, open PR count vs tripwire (>3), Qodo findings resolved ratio. Logged in standup note, not a dashboard - week-long project keeps overhead proportional.
