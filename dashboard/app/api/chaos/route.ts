import { NextResponse } from "next/server";
import { isValidAction, isAuthorized, parseLabOutcome, type ChaosAction } from "../../../lib/chaos";

const LAB_MCP_URL = process.env.LAB_MCP_URL ?? "http://172.17.0.1:8100/mcp";
const LAB_TOKEN = process.env.LAB_MCP_TOKEN ?? "";
// Operator key gates destructive chaos actions at the dashboard boundary.
// The human operator supplies it once in the UI; SENTRY agent calls go
// through the TrueForge approval gate instead (separate control plane).
const OPERATOR_KEY = process.env.OPERATOR_KEY ?? "";

export const dynamic = "force-dynamic";

function authHeaders(extra: Record<string, string> = {}): Record<string, string> {
  const h: Record<string, string> = { "Content-Type": "application/json", ...extra };
  if (LAB_TOKEN) h.Authorization = `Bearer ${LAB_TOKEN}`;
  return h;
}

async function callLab(action: ChaosAction): Promise<string> {
  const initRes = await fetch(LAB_MCP_URL, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize", params: {} }),
  });
  if (!initRes.ok) throw new Error(`MCP init failed (${initRes.status})`);
  const sid = initRes.headers.get("mcp-session-id") ?? "";
  await fetch(LAB_MCP_URL, {
    method: "POST",
    headers: authHeaders({ "mcp-session-id": sid }),
    body: JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }),
  });
  const callRes = await fetch(LAB_MCP_URL, {
    method: "POST",
    headers: authHeaders({ "mcp-session-id": sid }),
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 2,
      method: "tools/call",
      params: {
        name: action === "inject" ? "lab_inject_bad_deploy" : "lab_restore",
        arguments: {},
      },
    }),
  });
  const d = (await callRes.json()) as Parameters<typeof parseLabOutcome>[0];
  const outcome = parseLabOutcome(d);
  if (outcome.ok === false) throw new Error(outcome.error);
  return outcome.output;
}

export async function POST(req: Request) {
  const opKey = req.headers.get("x-operator-key");
  if (!isAuthorized(opKey, OPERATOR_KEY)) {
    return NextResponse.json({ ok: false, error: "unauthorized: bad operator key" }, { status: 401 });
  }
  let action: unknown;
  try {
    ({ action } = (await req.json()) as { action: unknown });
  } catch {
    return NextResponse.json({ ok: false, error: "invalid JSON body" }, { status: 400 });
  }
  if (!isValidAction(action)) {
    return NextResponse.json({ ok: false, error: "invalid action" }, { status: 400 });
  }
  try {
    const out = await callLab(action);
    return NextResponse.json({ ok: true, output: out });
  } catch (e) {
    return NextResponse.json({ ok: false, error: String(e instanceof Error ? e.message : e) }, { status: 502 });
  }
}
