<!-- Product repo: .github/PULL_REQUEST_TEMPLATE.md at bootstrap -->

## What

<!-- One paragraph: what changes and why it exists. Link the gate/task id from solid-plan.md (e.g. G1/T4). -->

## Why

<!-- Which judging criterion / wave gate this serves. If refactor: what proof it is behavior-preserving. -->

## Evidence

- [ ] Failing test written first, then implementation (link test file)
- [ ] Full suite green locally (`pnpm test`)
- [ ] Lint + typecheck clean
- [ ] No secrets in diff (`.env` untouched; placeholders only)

## How tested

<!-- Exact commands + expected output. For e2e/golden-loop changes: paste stage-by-stage assert results. -->

## Qodo review

<!-- Do not resolve this section manually. Address every finding in-thread: fix or reasoned rebuttal. Merge requires zero open threads. -->
