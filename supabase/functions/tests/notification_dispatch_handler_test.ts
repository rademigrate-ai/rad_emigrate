import {
  createNotificationDispatchHandler,
  safeSandboxTarget,
} from "../notification-dispatch/handler.ts";
const token = "TEST_ONLY_NOTIFICATION_WORKER_CANARY_123456";
const id = (number: number) =>
  `47000000-0000-4000-8000-${String(number).padStart(12, "0")}`;
const claim = () => ({
  id: id(1),
  notification_id: id(2),
  user_id: id(3),
  lease_token: id(4),
  channel: "email",
  transport: "sandbox",
  attempts: 1,
});
function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
type Changes = Partial<Parameters<typeof createNotificationDispatchHandler>[0]>;
async function exercise(
  changes: Changes = {},
  body: unknown = {},
  supplied = token,
  method = "POST",
) {
  const calls: { path: string; body: unknown; signal?: AbortSignal | null }[] =
    [];
  let sent = false;
  const handler = createNotificationDispatchHandler({
    enabled: true,
    supabaseUrl: "http://127.0.0.1:58321",
    invocationToken: token,
    database: async (path, init) => {
      calls.push({
        path,
        body: JSON.parse(String(init?.body ?? "{}")),
        signal: init?.signal,
      });
      if (path.includes("claim_")) {
        if (sent) return [];
        sent = true;
        return [claim()];
      }
      return true;
    },
    ...changes,
  });
  const response = await handler(
    new Request("https://edge.example.com/dispatch", {
      method,
      headers: {
        "x-rad-notification-token": supplied,
        "Content-Type": "application/json",
        Authorization: "Bearer TEST_ONLY_USER_JWT",
      },
      ...(method === "POST"
        ? { body: typeof body === "string" ? body : JSON.stringify(body) }
        : {}),
    }),
  );
  return {
    status: response.status,
    body: method === "OPTIONS" ? await response.text() : await response.json(),
    calls,
  };
}

Deno.test("dispatch endpoint: disabled/missing token/production target never reaches outbox", async () => {
  for (
    const options of [{ enabled: false }, { invocationToken: "short" }, {
      supabaseUrl: "https://inshddthftkhcdosoqcn.supabase.co",
      environment: "staging",
      stagingProject: "inshddthftkhcdosoqcn",
    }, { supabaseUrl: "https://ssssssssssssssssssss.supabase.co" }]
  ) {
    const x = await exercise(options);
    equal(x.status, 503);
    equal(x.calls.length, 0);
  }
});
Deno.test("dispatch endpoint: ordinary user JWT cannot replace the dedicated token", async () => {
  for (const value of ["", "wrong", token + "x", "x".repeat(513)]) {
    const x = await exercise({}, {}, value);
    equal(x.status, 403);
    equal(x.calls.length, 0);
  }
});
Deno.test("dispatch endpoint: safe methods never claim work", async () => {
  for (const method of ["OPTIONS", "GET"]) {
    const x = await exercise({}, {}, "", method);
    equal(x.calls.length, 0);
    equal(x.status, method === "OPTIONS" ? 200 : 405);
  }
});
Deno.test("dispatch endpoint: sandbox receipts preserve private lease attribution", async () => {
  const x = await exercise();
  equal(x.status, 200);
  equal(x.body.mode, "sandbox");
  equal(x.body.sandbox_receipts, 1);
  equal(x.calls.find((c) => c.path.includes("finish_"))!.body, {
    p_delivery_id: id(1),
    p_lease_token: id(4),
    p_success: true,
  });
  equal(x.calls.every((c) => c.signal instanceof AbortSignal), true);
  equal(JSON.stringify(x.body).includes(id(4)), false);
  equal(JSON.stringify(x.body).includes(token), false);
});
Deno.test("dispatch endpoint: malformed/foreign/oversized requests fail before claims", async () => {
  for (
    const body of [
      null,
      [],
      { user_id: id(3) },
      { limit: 0 },
      { limit: 21 },
      { limit: "1" },
      { limit: 1.5 },
      "{bad",
    ]
  ) {
    const x = await exercise({}, body);
    equal(x.status, 400);
    equal(x.calls.length, 0);
  }
  const x = await exercise({}, { extra: "x".repeat(5000) });
  equal(x.status, 413);
  equal(x.calls.length, 0);
});
Deno.test("dispatch endpoint: a bounded batch limit stops without an extra claim", async () => {
  let calls = 0;
  const x = await exercise({
    database: async (path) => {
      calls++;
      return path.includes("claim_") ? [claim()] : true;
    },
  }, { limit: 2 });
  equal(x.status, 200);
  equal(x.body.sandbox_receipts, 2);
  equal(calls, 4);
});
Deno.test("dispatch endpoint: malformed claims and backend secrets become fixed failures", async () => {
  for (
    const database of [async () => null, async () => {
      throw new Error("PRIVATE_DATABASE_CANARY");
    }]
  ) {
    const x = await exercise({ database });
    equal(x.status, 503);
    equal(x.body.error, "notification_dispatch_unavailable");
    equal(JSON.stringify(x.body).includes("CANARY"), false);
  }
});
Deno.test("dispatch endpoint: deadline aborts backend calls and exposes no diagnostics", async () => {
  let signal: AbortSignal | undefined;
  const x = await exercise({
    timeoutMs: 5,
    database: async (_path, init) => {
      signal = init?.signal as AbortSignal;
      return await new Promise(() => {});
    },
  });
  equal(x.status, 503);
  equal(signal?.aborted, true);
  equal(x.body.error, "notification_dispatch_unavailable");
});
Deno.test("dispatch endpoint: hosted sandbox requires explicit staging binding", () => {
  const project = "s".repeat(20), url = `https://${project}.supabase.co`;
  equal(safeSandboxTarget(url, "staging", project), true);
  for (
    const target of [
      url + "?prod=1",
      url + "/rest/v1",
      `https://user@${project}.supabase.co`,
      "https://inshddthftkhcdosoqcn.supabase.co",
    ]
  ) {
    equal(safeSandboxTarget(target, "staging", project), false);
  }
  equal(safeSandboxTarget(url, "production", project), false);
  equal(safeSandboxTarget(url, "staging", "t".repeat(20)), false);
});
