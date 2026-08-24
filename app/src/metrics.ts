import { Counter, Histogram, collectDefaultMetrics, Registry } from "prom-client";

export interface Metrics {
  registry: Registry;
  checkoutLatency: Histogram<string>;
  http5xx: Counter<string>;
}

export function createMetrics(): Metrics {
  const registry = new Registry();
  collectDefaultMetrics({ register: registry });

  const checkoutLatency = new Histogram({
    name: "checkout_latency_seconds",
    help: "Checkout request latency in seconds",
    buckets: [0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
    registers: [registry],
  });

  const http5xx = new Counter({
    name: "http_5xx_total",
    help: "Total number of 5xx responses",
    registers: [registry],
  });

  return { registry, checkoutLatency, http5xx };
}
