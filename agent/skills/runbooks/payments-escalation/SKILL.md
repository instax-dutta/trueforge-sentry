---
name: payments-escalation
description: Extended runbook for payment-service alerts. Use INSTEAD OF plain oncall-triage when the alert names payments or checkout specifically. Adds webhook-queue depth and payment-method breakdown checks.
---

# Payments Escalation Runbook

Extends oncall-triage for payment/checkout alerts:

1. Run standard triage steps 1-3 first (error rate + latency percentiles).
2. Additionally check webhook processing lag if a payments DB tool is attached.
3. Break errors down by payment method card/upi/cod if labels exist:
   `sum(rate(http_5xx_total[5m])) by (method)`
4. In the RCA, always include: time window, blast radius (which endpoints), first-bad timestamp, and the exact PromQL used.
5. Rollback recommendation format: target revision + expected recovery signature (the specific query that should return to baseline post-action).
