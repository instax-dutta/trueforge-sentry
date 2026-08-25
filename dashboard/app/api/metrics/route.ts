import { NextResponse } from "next/server";

const PROM_URL = process.env.PROMETHEUS_URL ?? "http://prometheus:9090";

export const dynamic = "force-dynamic";

async function instant(query: string): Promise<string | null> {
  const url = `${PROM_URL}/api/v1/query?query=${encodeURIComponent(query)}`;
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) return null;
  const d = (await res.json()) as { data: { result: { value: [number, string] }[] } };
  return d.data.result[0]?.value[1] ?? null;
}

export async function GET() {
  try {
    const [errRate, p95, total, latencyAvg] = await Promise.all([
      instant("sum(rate(http_5xx_total[5m])) or vector(0)"),
      instant("histogram_quantile(0.95, sum(rate(checkout_latency_seconds_bucket[5m])) by (le)) or vector(0)"),
      instant("sum(checkout_latency_seconds_count) or vector(0)"),
      instant("sum(rate(checkout_latency_seconds_sum[5m])) / clamp_min(sum(rate(checkout_latency_seconds_count[5m])), 0.001)"),
    ]);
    return NextResponse.json({
      ok: true,
      errRate: Number(errRate ?? 0),
      p95Seconds: Number(p95 ?? 0),
      totalCheckouts: Math.floor(Number(total ?? 0)),
      avgLatencyMs: Math.round(Number(latencyAvg ?? 0) * 1000),
    });
  } catch (e) {
    return NextResponse.json({ ok: false, error: String(e) }, { status: 502 });
  }
}
