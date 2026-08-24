import { buildApp } from "./server.js";

function parsePort(raw: string | undefined, fallback: number): number {
  const n = Number(raw);
  return Number.isInteger(n) && n > 0 && n < 65536 ? n : fallback;
}

const port = parsePort(process.env.SHOP_PORT, 3000);
const host = process.env.HOST ?? "0.0.0.0";

const app = await buildApp();
await app.listen({ port, host });
app.log.info(`shop listening on ${host}:${port}`);
