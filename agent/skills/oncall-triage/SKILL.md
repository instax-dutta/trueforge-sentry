---
name: oncall-triage
description: Read-only incident triage playbook for SENTRY. Use when investigating an alert or outage for any service. Covers metric queries, deploy correlation, log analysis, and when to stop before acting.
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
   b. Match each commit timestamp against the spike window (when error rate crossed threshold). Note: commit time is a proxy for deploy time; if Grafana deploy annotations or GitHub Deployments API data is available, prefer those for actual deploy timestamps.
   c. Identify the commit whose timestamp aligns closest to the regression onset - this is the suspected culprit.
   d. If the GitHub MCP has deploy status or annotation data, cross-reference for confirmation.
5. Compute all aggregations/ratios via code execution in the sandbox, not mental math.
6. Produce a verdict: suspected culprit commit SHA + commit timestamp + correlation evidence (error rate before/after, latency delta) + confidence level. State clearly whether the timestamp is commit time or confirmed deploy time.
7. STOP. Do not call any write/destructive tool. Recommend the action and wait for human approval.

Rules of engagement:
- Read-only tools are always allowed without asking.
- Any state-changing proposal must end the turn with an explicit approval request.
- If data is inconclusive after 3 query rounds, say so honestly instead of guessing.
