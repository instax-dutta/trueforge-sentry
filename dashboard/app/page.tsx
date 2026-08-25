"use client";

import { useCallback, useEffect, useState } from "react";

interface Metrics {
  ok: boolean;
  errRate: number;
  p95Seconds: number;
  totalCheckouts: number;
  avgLatencyMs: number;
}

function healthClass(errRate: number): string {
  if (errRate > 0.1) return "bad";
  if (errRate > 0.01) return "warn";
  return "ok";
}

export default function Home() {
  const [metrics, setMetrics] = useState<Metrics | null>(null);
  const [busy, setBusy] = useState<"inject" | "restore" | null>(null);
  const [banner, setBanner] = useState<{ kind: "ok" | "bad"; text: string } | null>(null);
  const [history, setHistory] = useState<{ at: string; text: string }[]>([]);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch("/api/metrics", { cache: "no-store" });
      setMetrics(await res.json());
    } catch {
      setMetrics(null);
    }
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 5000);
    return () => clearInterval(id);
  }, [refresh]);

  const chaos = useCallback(async (action: "inject" | "restore") => {
    setBusy(action);
    try {
      const res = await fetch("/api/chaos", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action }),
      });
      const d = await res.json();
      setBanner(d.ok ? { kind: "ok", text: `${action}: ${d.output}` } : { kind: "bad", text: `failed: ${d.error}` });
      setHistory((h) => [{ at: new Date().toISOString().slice(11, 19), text: action }, ...h].slice(0, 6));
      setTimeout(refresh, 3000);
    } catch (e) {
      setBanner({ kind: "bad", text: String(e) });
    } finally {
      setBusy(null);
    }
  }, [refresh]);

  const rate = metrics?.errRate ?? 0;

  return (
    <main className="wrap">
      <div className="grid">
        <div className="card">
          <h3>5xx rate (5m)</h3>
          <div className={`value ${healthClass(rate)}`}>{metrics ? metrics.errRate.toFixed(3) : "-"}<small>/s</small></div>
        </div>
        <div className="card">
          <h3>checkout p95</h3>
          <div className={`value ${metrics && metrics.p95Seconds > 1 ? "warn" : "ok"}`}>
            {metrics ? Math.round(metrics.p95Seconds * 1000) : "-"}<small>ms</small>
          </div>
        </div>
        <div className="card">
          <h3>total checkouts</h3>
          <div className="value">{metrics ? metrics.totalCheckouts : "-"}</div>
        </div>
      </div>

      <div className="section-title">Chaos Lab</div>
      <div className="card">
        <div className="chaos-row">
          <button className="danger" disabled={busy !== null || rate > 0.1} onClick={() => chaos("inject")}>
            Inject bad deploy
          </button>
          <button className="safe" disabled={busy !== null} onClick={() => chaos("restore")}>
            Restore healthy
          </button>
          {busy && <span>running {busy}...</span>}
        </div>
        {banner && <div className={`banner ${banner.kind}`}>{banner.text}</div>}
        {history.length > 0 && (
          <table style={{ marginTop: 14 }}>
            <thead><tr><th>time (UTC)</th><th>action</th></tr></thead>
            <tbody>
              {history.map((h, i) => (
                <tr key={i}><td>{h.at}</td><td>{h.text}</td></tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="section-title">Investigation</div>
      <div className="card">
        Open the TrueForge chat and ask SENTRY:
        <pre style={{ whiteSpace: "pre-wrap", color: "var(--amber)", margin: "10px 0 0" }}>
{`Investigate the payment-failures alert. Triage read-only using Grafana
and GitHub, then propose rollback via sentry-lab. Do not execute without approval.`}
        </pre>
        <p style={{ color: "var(--dim)" }}>
          Destructive proposals pause at a human Allow/Deny gate inside the chat.
        </p>
      </div>
    </main>
  );
}
