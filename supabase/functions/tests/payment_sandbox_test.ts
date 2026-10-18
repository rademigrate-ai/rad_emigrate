import {
  createPaymentSandboxHandler,
  type SandboxPaymentEvent,
} from "../payment-sandbox/handler.ts";
const now = Date.UTC(2026, 9, 18, 12, 0, 0);
const secret = "synthetic-local-only-hmac-secret-470000000";
const encoder = new TextEncoder();
const event = (): SandboxPaymentEvent => ({
  mode: "sandbox",
  event_id: "event-one",
  subscription_id: "subscription-one",
  user_id: "47000000-0000-4000-8000-000000000001",
  type: "payment_succeeded",
  sequence: 1,
  amount_minor: 100,
  currency: "TST",
  occurred_at: new Date(now - 10000).toISOString(),
  period_end: new Date(now + 86400000).toISOString(),
});
function equal(a: unknown, b: unknown) {
  if (JSON.stringify(a) !== JSON.stringify(b)) {
    throw new Error(`Expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
  }
}
async function signature(
  raw: string,
  timestamp = Math.floor(now / 1000),
  signingSecret = secret,
) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(signingSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const bytes = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${timestamp}.${raw}`),
  );
  return `t=${timestamp},v1=${
    Array.from(new Uint8Array(bytes), (n) => n.toString(16).padStart(2, "0"))
      .join("")
  }`;
}
type Options = {
  enabled?: boolean;
  url?: string;
  raw?: string;
  timestamp?: number;
  signingSecret?: string;
  tamper?: boolean;
  result?: unknown;
  databaseError?: boolean;
  method?: string;
};
async function exercise(value: unknown = event(), options: Options = {}) {
  const calls: Array<{ event: SandboxPaymentEvent; sha: string }> = [];
  const raw = options.raw ?? JSON.stringify(value);
  const signed = await signature(raw, options.timestamp, options.signingSecret);
  const handler = createPaymentSandboxHandler({
    enabled: options.enabled ?? true,
    supabaseUrl: options.url ?? "http://127.0.0.1:55321",
    secret,
    now: () => now,
    apply: async (event, sha) => {
      calls.push({ event, sha });
      if (options.databaseError) throw new Error("private-database-canary");
      return options.result ??
        { mode: "sandbox", duplicate: false, decision: "applied" };
    },
  });
  const method = options.method ?? "POST";
  const response = await handler(
    new Request("http://127.0.0.1/payment-sandbox", {
      method,
      headers: {
        "x-rad-sandbox-signature": signed,
        "Content-Type": "application/json",
      },
      ...(method === "POST" ? { body: options.tamper ? raw + " " : raw } : {}),
    }),
  );
  return {
    status: response.status,
    body: method === "OPTIONS" ? await response.text() : await response.json(),
    calls,
  };
}

Deno.test("payment sandbox: signed synthetic event passes only normalized allowlisted data", async () => {
  const x = await exercise();
  equal(x.status, 200);
  equal(x.body, { mode: "sandbox", duplicate: false, decision: "applied" });
  equal(x.calls[0].event, event());
  equal(/^[0-9a-f]{64}$/.test(x.calls[0].sha), true);
});
Deno.test("payment sandbox: disabled mode and hosted targets never reach persistence", async () => {
  for (
    const options of [
      { enabled: false },
      { url: "https://inshddthftkhcdosoqcn.supabase.co" },
      { url: "https://example.com" },
      { url: "http://user:pass@127.0.0.1:55321" },
    ]
  ) {
    const x = await exercise(event(), options);
    equal(x.status, 503);
    equal(x.calls.length, 0);
  }
});
Deno.test("payment sandbox: wrong HMAC and body tampering never reach persistence", async () => {
  for (
    const options of [{ signingSecret: "different-synthetic-key" }, {
      tamper: true,
    }]
  ) {
    const x = await exercise(event(), options);
    equal(x.status, 401);
    equal(x.calls.length, 0);
  }
});
Deno.test("payment sandbox: old and excessively future signature timestamps are rejected", async () => {
  for (const delta of [-301, 301]) {
    const x = await exercise(event(), {
      timestamp: Math.floor(now / 1000) + delta,
    });
    equal(x.status, 401);
    equal(x.calls.length, 0);
  }
});
Deno.test("payment sandbox: signed malformed JSON and collection bodies are rejected", async () => {
  for (const raw of ["{bad json}", "null", "[]", "42"]) {
    const x = await exercise(null, { raw });
    equal(x.status, 400);
    equal(x.calls.length, 0);
  }
});
Deno.test("payment sandbox: raw payload size is bounded before processing", async () => {
  const x = await exercise(null, { raw: "x".repeat(32769) });
  equal(x.status, 413);
  equal(x.calls.length, 0);
});
Deno.test("payment sandbox: unknown sensitive fields, wrong mode and invalid owner are rejected", async () => {
  for (
    const patch of [
      { card_number: "synthetic-never-stored" },
      { mode: "live" },
      { user_id: "other" },
      { type: ["payment_succeeded"] },
      { currency: "tst" },
    ]
  ) {
    const x = await exercise({ ...event(), ...patch });
    equal(x.status, 400);
    equal(x.calls.length, 0);
  }
});
Deno.test("payment sandbox: integer money, event order and period constraints are enforced", async () => {
  for (
    const patch of [
      { amount_minor: 0 },
      { amount_minor: -1 },
      { amount_minor: 1.5 },
      { amount_minor: 1000000001 },
      { sequence: 0 },
      { sequence: 1.5 },
      { period_end: null },
      { period_end: new Date(now - 20000).toISOString() },
      { occurred_at: new Date(now + 301000).toISOString() },
    ]
  ) {
    const x = await exercise({ ...event(), ...patch });
    equal(x.status, 400);
    equal(x.calls.length, 0);
  }
});
Deno.test("payment sandbox: cancellation has no paid amount or assumed active period", async () => {
  const x = await exercise({
    ...event(),
    type: "subscription_cancelled",
    sequence: 2,
    amount_minor: 0,
    period_end: null,
  });
  equal(x.status, 200);
  equal(x.calls[0].event.period_end, null);
});
Deno.test("payment sandbox: canonical hash is stable under JSON property order and whitespace", async () => {
  const first = await exercise();
  const reversed = Object.fromEntries(Object.entries(event()).reverse());
  const second = await exercise(reversed, {
    raw: JSON.stringify(reversed, null, 2),
  });
  equal(first.calls[0].sha, second.calls[0].sha);
  const changed = await exercise({ ...event(), amount_minor: 101 });
  equal(changed.calls[0].sha === first.calls[0].sha, false);
});
Deno.test("payment sandbox: duplicate and out-of-order decisions retain sandbox labels only", async () => {
  for (const decision of ["applied", "ignored_stale", "ignored_terminal"]) {
    const x = await exercise(event(), {
      result: {
        mode: "sandbox",
        duplicate: true,
        decision,
        api_key: "private-canary",
      },
    });
    equal(x.body, { mode: "sandbox", duplicate: true, decision });
    equal(JSON.stringify(x.body).includes("canary"), false);
  }
});
Deno.test("payment sandbox: persistence failures and malformed responses fail closed", async () => {
  for (
    const options of [{ databaseError: true }, {
      result: { mode: "live", duplicate: false, decision: "applied" },
    }, { result: { error: "private-canary" } }]
  ) {
    const x = await exercise(event(), options);
    equal(x.status, 503);
    equal(x.body, { error: "payment_sandbox_unavailable" });
  }
});
Deno.test("payment sandbox: safe methods never invoke persistence", async () => {
  for (const method of ["GET", "OPTIONS"]) {
    const x = await exercise(event(), { method });
    equal(x.status, method === "OPTIONS" ? 200 : 405);
    equal(x.calls.length, 0);
  }
});
