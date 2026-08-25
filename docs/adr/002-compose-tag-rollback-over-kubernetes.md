# ADR 002: Compose-tag rollback over kubernetes MCP

## Context

The rollback beat needs a real irreversible action gated by human approval. Two paths were considered: a local kind/k3s cluster driven by the community kubernetes MCP server (`kubectl rollout undo`), or swapping the shop container image tag via our own ops-MCP (the cookbook's bring-your-own-MCP pattern).

## Decision

Rollback runs through a custom `sentry-lab` MCP server that toggles compose environment flags (`CHAOS_ERROR_RATE`, `CHAOS_LATENCY_MS`) on the remote demo host. The `lab_restore` and `lab_inject_bad_deploy` tools carry an explicit approval list in the agent manifest, so every call pauses at the TrueForge approval gate.

## Consequences

One fewer cluster to provision and no k8s flake risk during recording; the compose swap is deterministic and reversible within seconds, which keeps the golden-loop wall-clock inside the 90-second target. The approval card still shows tool name, args, and blast radius, so the control-and-safety story is identical to the k8s path. Cost: the MCP server is ours to maintain, and judges may note we skipped the community kubernetes connector - mitigated by README wording ("compose-tag rollback chosen for deterministic demos; the same manifest pattern works with `require_approval_for_tools` on any destructive tool").

Rejected alternatives: kind/k3d + kubernetes MCP (extra moving part, slower rollout semantics, flake risk on camera); raw docker exec from the agent (no MCP boundary, no approval annotation, weakens the harness story).
