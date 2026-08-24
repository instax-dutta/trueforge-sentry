/**
 * RED contract tests for the victim shop service (wave G1/T4).
 * These tests are written FIRST per docs/TDD-PROTOCOL.md.
 * They fail until src/ implements the contract.
 */
import { describe, it, expect, beforeAll, afterAll } from "vitest";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../src/server.js";

describe("shop service contract", () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = await buildApp({ seed: true });
    await app.ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it("GET /orders returns seeded order rows", async () => {
    const res = await app.inject({ method: "GET", url: "/orders" });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(Array.isArray(body.orders)).toBe(true);
    expect(body.orders.length).toBeGreaterThanOrEqual(3);
    for (const o of body.orders) {
      expect(o).toHaveProperty("id");
      expect(o).toHaveProperty("item");
      expect(o).toHaveProperty("amount");
      expect(typeof o.amount).toBe("number");
    }
  });

  it("GET /payments returns seeded payment rows", async () => {
    const res = await app.inject({ method: "GET", url: "/payments" });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(Array.isArray(body.payments)).toBe(true);
    expect(body.payments.length).toBeGreaterThanOrEqual(3);
  });

  it("POST /checkout returns 200 with a transaction id on the happy path", async () => {
    const res = await app.inject({
      method: "POST",
      url: "/checkout",
      payload: { item: "sku-1", amount: 42.5 },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ status: "approved" });
    expect(res.json().transactionId).toMatch(/^txn_/);
  });

  it("GET /metrics exposes Prometheus checkout histogram and 5xx counter", async () => {
    // generate some traffic so counters are non-zero
    await app.inject({ method: "POST", url: "/checkout", payload: { item: "x", amount: 1 } });
    const res = await app.inject({ method: "GET", url: "/metrics" });
    expect(res.statusCode).toBe(200);
    const text = res.body;
    expect(text).toContain("checkout_latency_seconds");
    expect(text).toContain("http_5xx_total");
  });

  it("CHAOS_LATENCY_MS delays /checkout responses", async () => {
    const chaos = await buildApp({ seed: false, chaosLatencyMs: 250 });
    await chaos.ready();
    const start = Date.now();
    await chaos.inject({ method: "POST", url: "/checkout", payload: { item: "x", amount: 1 } });
    const elapsed = Date.now() - start;
    expect(elapsed).toBeGreaterThanOrEqual(230); // small scheduling margin
    await chaos.close();
  });

  it("CHAOS_ERROR_RATE makes ~half of /checkout calls return 503", async () => {
    const chaos = await buildApp({ seed: false, chaosErrorRate: 0.5 });
    await chaos.ready();
    let errors = 0;
    const N = 40;
    for (let i = 0; i < N; i++) {
      const res = await chaos.inject({ method: "POST", url: "/checkout", payload: { item: "x", amount: 1 } });
      if (res.statusCode === 503) errors++;
    }
    // deterministic PRNG seeded by request count -> assert wide window
    expect(errors).toBeGreaterThan(N * 0.2);
    expect(errors).toBeLessThan(N * 0.8);
    await chaos.close();
  });
});
