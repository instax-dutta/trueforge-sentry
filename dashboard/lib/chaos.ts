// Pure helpers extracted for unit testing (Qodo finding: missing tests).

export type ChaosAction = "inject" | "restore";

export function isValidAction(a: unknown): a is ChaosAction {
  return a === "inject" || a === "restore";
}

export function isAuthorized(key: string | null, operatorKey: string): boolean {
  if (!operatorKey) return true; // keyless local deployments
  return key !== null && key === operatorKey;
}

export function parseLabOutcome(d: {
  result?: { isError?: boolean; content?: { text?: string }[] };
  error?: { message?: string };
}): { ok: true; output: string } | { ok: false; error: string } {
  if (d.error) return { ok: false, error: d.error.message ?? "MCP error" };
  const textOut = d.result?.content?.[0]?.text ?? "";
  if (d.result?.isError || textOut.startsWith("error")) {
    return { ok: false, error: textOut || "lab tool failed" };
  }
  return { ok: true, output: textOut || "completed" };
}
