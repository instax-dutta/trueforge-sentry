---
name: oncall-triage
description: Incident triage playbook for SENTRY. Use when investigating an alert or outage for any service. Covers metric queries, deploy correlation via GitHub commits, log analysis, approval gate, rollback, recovery verification, and RCA issue filing.
---

# On-call Triage

When asked to investigate an alert or anomaly:

1. Classify the alert from the message (payment-failures, latency, error-rate, OOM).
2. Query Prometheus for the affected signal:
   - Error rate: `sum(rate(http_5xx_total[30m]))`
   - Checkout latency p95: `histogram_quantile(0.95, sum(rate(checkout_latency_seconds_bucket[5m])) by (le))`
3. Compare against baseline. State numbers exactly as returned by tools - never estimate mentally.
4. If metrics are elevated, look for a cause:
   a. Query GitHub for recent commits on the repo (`list_commits` with the service repo, last 10 commits).
   b. Establish the spike window with data, not assumption: run a range query (e.g., query_prometheus for `sum(rate(http_5xx_total[5m]))` sampled over the last 60 minutes) and have sandbox code report the timestamp where the rate first crossed 2x the pre-incident baseline. That crossing time is the regression onset.
   c. Match commit timestamps against [onset minus 10m, onset plus 2m]. Note: commit time is a proxy for deploy time; if Grafana deploy annotations or GitHub Deployments API data is available, prefer those for actual deploy timestamps.
   d. Identify the commit whose timestamp aligns closest to the regression onset - this is the suspected culprit.
   e. If the GitHub MCP has deploy status or annotation data, cross-reference for confirmation.
5. Compute all aggregations/ratios via code execution in the sandbox, not mental math.
6. Produce a verdict: suspected culprit commit SHA + commit timestamp + correlation evidence (error rate before/after, latency delta) + confidence level. State clearly whether the timestamp is commit time or confirmed deploy time.
7. Propose the rollback tool call (e.g., `lab_restore` via sentry-lab MCP). This triggers the TrueForge approval gate - the harness emits `tool.approval_required` and pauses. Wait for the human to click Allow or Deny.

## After Approval (human clicks Allow)

The harness executes the pending rollback call automatically - no second tool call needed.

8. Poll Prometheus until error rate returns to baseline (query every 10s, timeout 120s). Use the same PromQL from step 2.
9. File a GitHub issue on the repo with the RCA body:
    - Title: `RCA: <alert-name> - <culprit-commit-sha> - <date>`
    - Body must include: incident timeline, error rate before/during/after, suspected culprit commit + deploy timestamp, PromQL queries used, recovery verification query + result, and recommended follow-up actions.
    - This uses the GitHub MCP create_issue tool, which will trigger an approval gate - this is expected and good for the demo.
10. Emit a Generative UI summary card with before/after numbers:
    - Incident timeline (alert fired -> triage started -> cause identified -> rollback approved -> recovery verified)
    - Error rate chart: baseline value, peak during incident, post-recovery value
    - Culprit: commit SHA + deploy timestamp
    - Resolution: what was done, verification query + result
    - This streams as an inline React card in the chat, not a markdown image.

Rules of engagement:
- Read-only tools are always allowed without asking.
- Any state-changing proposal must end the turn with an explicit approval request.
- If data is inconclusive after 3 query rounds, say so honestly instead of guessing.
