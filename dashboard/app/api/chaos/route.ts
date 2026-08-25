import { NextResponse } from "next/server";

const LAB_MCP_URL = process.env.LAB_MCP_URL ?? "http://lab-mcp:8100/mcp";
const LAB_TOKEN = process.env.LAB_MCP_TOKEN ?? "";

export const dynamic = "force-dynamic";

type Action = "status" | "inject" | "restore";

interface JsonRpcResponse {
  result?: { content?: { text?: string }[] };
  error?: unknown;
}

async function callLab(action: Exclude<Action, "status">) {
  const initRes = await fetch(LAB_MCP_URL, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize", params: {} }),
  });
  if (!initRes.ok) throw new Error(`init failed ${initRes.status}`);
  const sid = initRes.headers.get("mcp-session-id") ?? "";
  // notifications/initialized
  await fetch(LAB_MCP_URL, {
    method: "POST",
    headers: { ...authHeaders(), "mcp-session-id": sid },
    body: JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }),
  });
  const callRes = await fetch(LAB_MCP_URL, {
    method: "POST",
    headers: { ...authHeaders(), "mcp-session-id": sid },
    body: JSON.stringify({
      jsonrpc: "2.0", id: 2, method: "tools/call",
      params: { name: action === "inject" ? "lab_inject_bad_deploy" : "lab_restore", arguments: {} },
    }),
  });
  const d = (await callRes.json()) as JsonRpcResponse;
  return d.result?.content?.[0]?.text ?? "done";
}

function authHeaders(): Record<string, string> {
  const h: Record<string, string> = { "Content-Type": "application/json" };
  if (LAB_TOKEN) h.Authorization = `Bearer ${LAB_TOKEN}`;
  return h;
}

export async function POST(req: Request) {
  try {
    const { action } = (await req.json()) as { action: Action };
    if (action !== "inject" && action !== "restore") {
      return NextResponse.json({ ok: false, error: "invalid action" }, { status: 400 });
    }
    const out = await callLab(action);
    return NextResponse.json({ ok: true, output: out });
  } catch (e) {
    return NextResponse.json({ ok: false, error: String(e) }, { status: 502 });
  }
}
