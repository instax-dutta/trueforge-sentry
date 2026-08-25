"use client";

import { useCallback, useEffect, useState } from "react";

interface Metrics {
  ok: true;
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
  const [metricsError, setMetricsError] = useState<string | null>(null);
  const [busy, setBusy] = useState<"inject" | "restore" | null>(null);
  const [banner, setBanner] = useState<{ kind: "ok" | "bad"; text: string } | null>(null);
  const [history, setHistory] = useState<{ at: string; text: string }[]>([]);
  const [confirming, setConfirming] = useState<"inject" | "restore" | null>(null);
  const [opKey, setOpKey] = useState<string>("");

  useEffect(() => {
    setOpKey(sessionStorage.getItem("sentry-operator-key") ?? "");
  }, []);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch("/api/metrics", { cache: "no-store" });
      const payload = await res.json();
      // Only accept well-formed success payloads; surface errors explicitly.
      if (res.ok && payload.ok === true) {
        setMetrics(payload as Metrics);
        setMetricsError(null);
      } else {
        setMetrics(null);
        setMetricsError(payload.error ?? `HTTP ${res.status}`);
      }
    } catch (e) {
      setMetrics(null);
      setMetricsError(String(e));
    }
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 5000);
    return () => clearInterval(id);
  }, [refresh]);

  const executeChaos = useCallback(
    async (action: "inject" | "restore") => {
      setBusy(action);
      try {
        const res = await fetch("/api/chaos", {
          method: "POST",
          headers: { "Content-Type": "application/json", "x-operator-key": opKey },
          body: JSON.stringify({ action }),
        });
        const d = await res.json();
        if (!res.ok || !d.ok) throw new Error(d.error ?? `HTTP ${res.status}`);
        setBanner({ kind: "ok", text: `${action}: ${d.output}` });
        setHistory((h) => [{ at: new Date().toISOString().slice(11, 19), text: action }, ...h].slice(0, 6));
        setTimeout(refresh, 3000);
      } catch (e) {
        setBanner({ kind: "bad", text: String(e instanceof Error ? e.message : e) });
      } finally {
        setBusy(null);
        setConfirming(null);
      }
    },
    [opKey, refresh],
  );

  const rate = metrics?.errRate ?? 0;

  return (
    <main className="wrap">
      {metricsError && <div className="banner bad">metrics unavailable: {metricsError}</div>}

      <div className="grid">
        <div className="card">
          <h3>5xx rate (5m)</h3>
          <div className={`value ${metrics ? healthClass(rate) : ""}`}>
            {metrics ? metrics.errRate.toFixed(3) : "-"}
            <small>/s</small>
          </div>
        </div>
        <div className="card">
          <h3>checkout p95</h3>
          <div className={`value ${metrics && metrics.p95Seconds > 1 ? "warn" : metrics ? "ok" : ""}`}>
            {metrics ? Math.round(metrics.p95Seconds * 1000) : "-"}
            <small>ms</small>
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
          <button
            className="danger"
            disabled={busy !== null}
            onClick={() => setConfirming("inject")}
          >
            Inject bad deploy
          </button>
          <button className="safe" disabled={busy !== null} onClick={() => chaos("restore")}>
            Restore healthy
          </button>
          {busy && <span>running {busy}...</span>}
        </div>

        {confirming && (
          <div className="banner warnbox">
            <p style={{ margin: "0 0 10px" }}>
              This will change live stack state (CHAOS_ERROR_RATE). Confirm operator action.
            </p>
            {!opKey && (
              <input
                type="password"
                placeholder="operator key"
                onChange={(e) => {
                  setOpKey(e.target.value);
                  sessionStorage.setItem("sentry-operator-key", e.target.value);
                }}
                style={{ marginBottom: 10, padding: 8, width: "100%", background: "#0b0f14", color: "var(--text)", border: "1px solid var(--panel-edge)", borderRadius: 4 }}
              />
            )}
            <div className="chaos-row">
              <button className="danger" disabled={busy !== null} onClick={() => executeChaos(confirming)}>
                Confirm {confirming}
              </button>
              <button onClick={() => setConfirming(null)}>Cancel</button>
            </div>
          </div>
        )}

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
