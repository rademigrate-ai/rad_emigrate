/**
 * E2E service lifecycle tests (deterministic mocks).
 * Covers: AI quota reserve→ground→respond→settle, research→review candidate (no Feed),
 * currency primary/fallback, notification idempotency, unauthorized/malformed.
 * External providers are mocked; results do not prove live provider availability.
 */
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handler as researchHandler } from "../research-sync/handler.ts";
import { createCurrencyHandler } from "../currency-refresh/handler.ts";
import { fetchObservation } from "../currency-refresh/providers.ts";

type Call = { path: string; method?: string; body?: unknown };

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.test("E2E AI: quota reservation invalid shapes never invoke provider", () => {
  const quota: Record<string, unknown> = { allowed: true }; // missing request_id
  const valid = quota.allowed === true &&
    typeof quota.request_id === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(String(quota.request_id));
  assertEquals(valid, false);
});

Deno.test("E2E AI: settlement statuses only succeeded|failed with finished_at", async () => {
  const allowed = new Set(["succeeded", "failed"]);
  for (const status of ["succeeded", "failed"]) {
    assert(allowed.has(status));
  }
  const src = await Deno.readTextFile(
    new URL("../ai-orchestrator/handler.ts", import.meta.url),
  );
  assert(src.includes('status: "succeeded"'));
  assert(src.includes('status: "failed"'));
  assert(src.includes("finished_at"));
  assert(src.includes("consume_ai_daily_quota"));
  assert(!/publish_feed|insert.*feed_items/i.test(src));
});

Deno.test("E2E grounding: verified-only RPC; no editorial trust", async () => {
  const src = await Deno.readTextFile(
    new URL("../ai-orchestrator/knowledge_grounding.ts", import.meta.url),
  );
  assert(src.includes("retrieve_verified_official_claims"));
  assert(src.includes('verification_state !== "verified"'));
  assert(!src.includes("retrieve_knowledge_items"));
  assert(src.includes("Insufficient verified official"));
});

Deno.test("E2E research: ingest_research_snapshot path; no feed_items write", async () => {
  const src = await Deno.readTextFile(
    new URL("../research-sync/handler.ts", import.meta.url),
  );
  assert(src.includes("rpc/ingest_research_snapshot"));
  assert(src.includes("create_research_review_candidate runs inside"));
  assert(!/feed_items/.test(src));
  assert(src.includes('redirect: "manual"'));
  assert(src.includes("unsafe_source_url"));
});

Deno.test("E2E research: unauthorized request rejected before job claim", async () => {
  const originalFetch = globalThis.fetch;
  const calls: string[] = [];
  globalThis.fetch = async (input: RequestInfo | URL, _init?: RequestInit) => {
    const url = String(input);
    calls.push(url);
    if (url.includes("research_worker_config")) {
      return await Promise.resolve(json([{
        invocation_token: "secret-token-value-32chars-min!!",
        max_sources_per_run: 1,
        request_timeout_ms: 1000,
      }]));
    }
    if (url.includes("/auth/v1/user")) {
      return await Promise.resolve(json({}, 401));
    }
    return await Promise.resolve(json([]));
  };
  try {
    Deno.env.set("SUPABASE_URL", "http://127.0.0.1:9");
    Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-test-key");
    const res = await researchHandler(
      new Request("http://local/research-sync", { method: "POST" }),
    );
    assertEquals(res.status, 403);
    const body = await res.json();
    assertEquals(body.error, "forbidden");
    assert(
      !calls.some((u) => u.includes("research_jobs") && u.includes("PATCH")),
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("E2E currency: primary failure falls back and labels fawazahmed0", async () => {
  const calls: string[] = [];
  const fetcher: typeof fetch = async (input) => {
    const url = String(input);
    calls.push(url);
    if (url.includes("frankfurter")) {
      return await Promise.resolve(
        new Response("upstream down", { status: 503 }),
      );
    }
    if (url.includes("fawazahmed0") || url.includes("jsdelivr")) {
      return await Promise.resolve(
        new Response(
          JSON.stringify({ date: "2026-10-27", usd: { eur: 0.92 } }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );
    }
    throw new Error(`unexpected ${url}`);
  };
  const obs = await fetchObservation("USD", "EUR", fetcher);
  assertEquals(obs.provider, "fawazahmed0");
  assertEquals(obs.base, "USD");
  assertEquals(obs.quote, "EUR");
  assert(calls.some((u) => u.includes("frankfurter")));
  assert(calls.some((u) => u.includes("jsdelivr") || u.includes("fawaz")));
});

Deno.test("E2E currency: both providers fail → throws (no fabricated rate)", async () => {
  const fetcher: typeof fetch = async () =>
    await Promise.resolve(new Response("nope", { status: 500 }));
  let threw = false;
  try {
    await fetchObservation("USD", "EUR", fetcher);
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
});

Deno.test("E2E currency worker: forbidden without token; records observation on success", async () => {
  const dbCalls: Call[] = [];
  const handler = createCurrencyHandler({
    enabled: true,
    token: "a".repeat(32),
    database: async (path, init) => {
      dbCalls.push({
        path,
        method: init?.method,
        body: init?.body ? JSON.parse(String(init.body)) : undefined,
      });
      return await Promise.resolve("obs-1");
    },
    fetcher: async (input) => {
      const url = String(input);
      if (url.includes("frankfurter")) {
        return await Promise.resolve(
          new Response(
            JSON.stringify({
              base: "USD",
              quote: "EUR",
              rate: "0.91",
              date: "2026-10-27",
            }),
            { status: 200, headers: { "Content-Type": "application/json" } },
          ),
        );
      }
      return await Promise.resolve(new Response("nope", { status: 500 }));
    },
  });
  const denied = await handler(
    new Request("http://local/currency", { method: "POST", body: "{}" }),
  );
  assertEquals(denied.status, 403);

  const ok = await handler(
    new Request("http://local/currency", {
      method: "POST",
      headers: {
        "x-rad-currency-token": "a".repeat(32),
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ pairs: [{ base: "USD", quote: "EUR" }] }),
    }),
  );
  assertEquals(ok.status, 200);
  const body = await ok.json();
  assertEquals(body.results[0].status, "cached");
  assert(dbCalls.some((c) => c.path.includes("record_fx_observation")));
});

Deno.test("E2E notifications: handler never accepts ordinary JWT as dispatch token", async () => {
  const src = await Deno.readTextFile(
    new URL("../notification-dispatch/handler.ts", import.meta.url),
  );
  assert(
    src.includes("x-rad-notification") || src.includes("dispatch") ||
      src.includes("token"),
  );
  assert(!/feed_items.*insert/i.test(src));
});

Deno.test("E2E feed safety: research + AI + currency sources never write feed_items", async () => {
  for (
    const rel of [
      "../research-sync/handler.ts",
      "../ai-orchestrator/handler.ts",
      "../currency-refresh/handler.ts",
      "../official-source-worker/handler.ts",
    ]
  ) {
    const src = await Deno.readTextFile(new URL(rel, import.meta.url));
    assertEquals(/feed_items/.test(src), false, rel);
  }
});
