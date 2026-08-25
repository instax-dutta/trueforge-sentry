# ADR 003: Model selection via live tool-calling probes

## Context

SENTRY needs a model that reliably makes multi-step tool calls (Grafana query, GitHub commits, sentry-lab rollback) under the TrueForge harness. The hackathon requires bringing our own model key. Candidates were evaluated on tool-call reliability, latency, and cost - not raw reasoning quality.

## Decision

Route through a personal OpenAI-compatible gateway (`omni.aeglyn.site/v1`) with three tiers selected by live probes on Aug 23: dev iteration on `nemotron-3.5-lightning-free` (~3s latency, clean JSON tool calls), demo takes on `nemotron-3-ultra-free` (~21s, strongest reasoning for the recorded run), slow fallback lane `hy3-free` then `x-preview-f-free`. Sessions use sanitized two-segment model names; raw slashed FQNs resolve only upstream.

## Consequences

One-click model swap is a TrueForge feature we demo explicitly - the same manifest works across providers, which echoes the sponsor benchmark story (TrueForge on GLM-5.2 = 75% cheaper at same accuracy). Operational caveats learned from probing: gateway intermittently emits invalid JSON on reasoning-heavy routes (selected routes parse strictly clean), `max_tokens >= 200` needed for fallback lanes, and capacity-busy 503s require a fresh session retry (the e2e script automates this).

Rejected alternatives: funded API keys (none materialized; free tier sufficient); Ollama Cloud flagships (all Pro-gated since mid-2026, 403 on free seats); groq gpt-oss route (upstream maps to nonexistent qwen3-32b). The GLM-5.2 benchmark model is cited in the blog but not runnable free anywhere in this pool.
