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
 * Deterministic LCG in [0,1), seeded per app instance so chaos behavior is
 * reproducible across test runs regardless of module-global state.
 */
function makePrng(seed = 42): () => number {
  let s = seed;
  return () => {
    s = (s * 1103515245 + 12345) % 2147483648;
    return s / 2147483648;
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
    const end = metrics.checkoutLatency.startTimer();
    if (latencyMs > 0) await sleep(latencyMs);

    if (errorRate > 0 && prng() < errorRate) {
      metrics.http5xx.inc();
      end();
      return reply.status(503).send({ status: "gateway_unavailable" });
    }

    const body = (request.body ?? {}) as { item?: string; amount?: number };
    end();
    return {
      status: "approved",
      transactionId: nextTransactionId(),
      item: body.item ?? null,
      amount: body.amount ?? null,
    };
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
