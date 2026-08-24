# SENTRY

> An on-call incident responder with a licence to act - built on [TrueForge](https://github.com/truefoundry/trueforge), The Agent Harness Hackathon, Aug 24-30 2026.

When a payment-failures alert fires, SENTRY investigates over MCP (Grafana/Prometheus metrics, GitHub deploy history, service logs), correlates the cause in an isolated sandbox, then **holds at a human approval gate** before rolling anything back. After recovery it verifies the fix and files an RCA issue.

**Status:** bootstrap. Architecture and wave plan land in this PR's wake; this README grows into the full harness story as components merge.

## Quickstart (coming online during Wave G1-G2)

```bash
cp .env.example .env            # fill placeholders
docker compose up -d            # victim shop + prometheus + grafana
# TrueForge hosted: see docs/ (upstream clone + compose)
```

## License

MIT
