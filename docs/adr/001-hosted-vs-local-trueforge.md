# ADR 001: Hosted TrueForge over local standalone

## Context

TrueForge runs two ways: local `npx @truefoundry/trueforge` (port 8790, SQLite, zero deps) or hosted `docker compose up` from an upstream clone (port 8791, Postgres + Redis). The demo requires session persistence - killing the server mid-investigation and resuming with the same session ID is a named harness feature and one of the five Double-O signals.

## Decision

Run TrueForge in hosted mode (`docker compose up --build`, port 8791, Postgres-backed sessions) from day one. Local mode was used only for a pre-window smoke test.

## Consequences

Postgres-backed sessions make the persistence restart beat real rather than simulated - a `docker compose restart trueforge` mid-session resumes cleanly because state lives outside the server process. The trade-off is a heavier bring-up (three containers instead of one) which we accept because the demo host (pelican) has headroom, and judges evaluating "survives reconnects" will not accept SQLite-file claims without seeing the restart on camera.

Rejected alternatives: local-only (persistence story collapses under scrutiny); managed cloud deployment (violates the own-your-stack rule and adds network flake to a live demo).
