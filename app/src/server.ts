import Fastify, { type FastifyInstance } from "fastify";
import { createMetrics, type Metrics } from "./metrics.js";
import { seedOrders, seedPayments } from "./seed.js";

export interface BuildAppOptions {
  seed?: boolean;
  chaosLatencyMs?: number;
  chaosErrorRate?: number;
}

let requestCounter = 0;

/**
 * Deterministic 32-bit LCG in [0,1), seeded per app instance so chaos behavior
 * is reproducible across test runs regardless of module-global state.
 * Math.imul keeps the multiply exact within uint32 range (Qodo finding #1).
 */
function makePrng(seed = 42): () => number {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(s, 1103515245) + 12345) >>> 0;
    return s / 2 ** 32;
  };
}

function nextTransactionId(): string {
  requestCounter += 1;
  return `txn_${Date.now().toString(36)}_${requestCounter.toString(36)}`;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export async function buildApp(opts: BuildAppOptions = {}): Promise<FastifyInstance> {
  const app = Fastify({ logger: false });
  const metrics: Metrics = createMetrics();
  const latencyMs = opts.chaosLatencyMs ?? Number(process.env.CHAOS_LATENCY_MS ?? 0);
  const errorRate = opts.chaosErrorRate ?? Number(process.env.CHAOS_ERROR_RATE ?? 0);
  const prng = makePrng(42);

  app.get("/orders", async () => {
    return { orders: opts.seed === false ? [] : seedOrders() };
  });

  app.get("/payments", async () => {
    return { payments: opts.seed === false ? [] : seedPayments() };
  });

  app.post("/checkout", async (request, reply) => {
    if (latencyMs > 0) await sleep(latencyMs);

    if (errorRate > 0 && prng() < errorRate) {
      return reply.status(503).send({ status: "gateway_unavailable" });
    }

    const body = (request.body ?? {}) as { item?: string; amount?: number };
    return {
      status: "approved",
      transactionId: nextTransactionId(),
      item: body.item ?? null,
      amount: body.amount ?? null,
    };
  });

  // Latency + 5xx accounting for ALL checkout outcomes, measured at response
  // completion (Qodo findings #2 and #4): covers chaos 503s and any real error.
  app.addHook("onRequest", async (_request, reply) => {
    (reply as unknown as { elapsed: number }).elapsed = Date.now();
  });
  app.addHook("onResponse", async (request, reply) => {
    if (request.raw.url && request.raw.url.startsWith("/checkout")) {
      const started = (reply as unknown as { elapsed?: number }).elapsed ?? Date.now();
      metrics.checkoutLatency.observe((Date.now() - started) / 1000);
      if (reply.statusCode >= 500) metrics.http5xx.inc();
    }
  });

  app.get("/metrics", async (_request, reply) => {
    reply.header("content-type", metrics.registry.contentType);
    return metrics.registry.metrics();
  });

  // Expose for operational tooling without reaching into internals.
  app.decorate("chaosConfig", { latencyMs, errorRate });

  return app;
}

declare module "fastify" {
  interface FastifyInstance {
    chaosConfig: { latencyMs: number; errorRate: number };
  }
}
