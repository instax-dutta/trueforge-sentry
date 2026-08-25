import { describe, it, expect } from "vitest";
import { isValidAction, isAuthorized, parseLabOutcome } from "../lib/chaos";

describe("chaos action validation", () => {
  it("accepts inject and restore", () => {
    expect(isValidAction("inject")).toBe(true);
    expect(isValidAction("restore")).toBe(true);
  });
  it("rejects everything else", () => {
    expect(isValidAction("status")).toBe(false);
    expect(isValidAction("")).toBe(false);
    expect(isValidAction(undefined)).toBe(false);
    expect(isValidAction(null)).toBe(false);
  });
});

describe("operator key authorization", () => {
  it("requires matching key when one is configured", () => {
    expect(isAuthorized("secret", "secret")).toBe(true);
    expect(isAuthorized("wrong", "secret")).toBe(false);
    expect(isAuthorized(null, "secret")).toBe(false);
  });
  it("allows keyless local deployments", () => {
    expect(isAuthorized(null, "")).toBe(true);
    expect(isAuthorized("anything", "")).toBe(true);
  });
});

describe("lab outcome parsing", () => {
  it("propagates MCP isError as failure", () => {
    const r = parseLabOutcome({
      result: { isError: true, content: [{ text: "error: docker daemon down" }] },
    });
    expect(r).toEqual({ ok: false, error: "error: docker daemon down" });
  });
  it("propagates jsonrpc error objects", () => {
    const r = parseLabOutcome({ error: { message: "Invalid session ID" } });
    expect(r).toEqual({ ok: false, error: "Invalid session ID" });
  });
  it("returns output text on success", () => {
    const r = parseLabOutcome({
      result: { content: [{ text: "bad deploy injected." }] },
    });
    expect(r).toEqual({ ok: true, output: "bad deploy injected." });
  });
});
