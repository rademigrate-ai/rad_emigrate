Deno.env.set("SUPABASE_URL", "https://db.example.com");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-only-service-canary");
const { handler } = await import("../ai-orchestrator/index.ts");

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}
const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });
const runtime = (provider = "a", model = "first") => ({
  provider_id: provider, provider_slug: provider, adapter: "openai_compatible",
  base_url: `https://${provider}.example.com/v1`, model_id: model, model_slug: model,
  max_output_tokens: 100, request_timeout_seconds: 5, max_retries: 3,
  api_key: "test-only-credential-canary", credential_version: 1,
});
type R = ReturnType<typeof runtime>;
type Options = {
  chain?: R[]; status?: number[]; timeout?: boolean; discovery?: string[];
  persistFails?: boolean; chainFails?: boolean; role?: string;
};
async function exercise(options: Options = {}, payload: Record<string, unknown> = {}) {
  Deno.env.set("SUPABASE_URL", "https://db.example.com");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-only-service-canary");
  const original = globalThis.fetch;
  const calls: Array<{ path: string; body: any; headers: Record<string, string> }> = [];
  let providerCalls = 0;
  globalThis.fetch = async (input, init) => {
    const url = String(input);
    const body = init?.body ? JSON.parse(String(init.body)) : null;
    const headers = Object.fromEntries(new Headers(init?.headers));
    calls.push({ path: url, body, headers });
    if (url.includes("/auth/v1/user")) return response({ id: "user-one" });
    if (url.includes("/rest/v1/")) {
      const path = url.split("/rest/v1/")[1];
      if (path.startsWith("profiles?")) return response([{ role: options.role ?? "super_admin" }]);
      if (path.startsWith("ai_usage_limits?")) return response([{ daily_requests: 50, daily_output_tokens: 1000 }]);
      if (path === "ai_requests?select=id") return response([{ id: "request-one" }]);
      if (path.startsWith("ai_requests?id=")) return options.persistFails ? response({}, 500) : response(null);
      if (path === "rpc/get_ai_runtime_chain_versioned") return options.chainFails ? response({}, 500) : response(options.chain ?? [runtime(), runtime("a", "second"), runtime("b", "third")]);
      if (path === "rpc/get_ai_provider_runtime_versioned") return response([runtime()]);
      if (path.startsWith("ai_models?select=id,slug,max_output_tokens")) return response([{ id: "first", slug: "first" }]);
      if (path === "rpc/ingest_ai_model_catalogue") return response({discovered: body.p_models.length, added: body.p_models.length, removed: 1});
      return response([]);
    }
    if (url.endsWith("/models")) return response({ data: (options.discovery ?? ["one", "two", "one"]).map(id => ({ id })) });
    const attempt = providerCalls++;
    if (options.timeout && attempt === 0) throw new DOMException("sensitive upstream URL", "TimeoutError");
    const status = options.status?.[attempt] ?? 200;
    return status === 200 ? response({ choices: [{ message: { content: "Accepted response" } }], usage: { completion_tokens: 4 } }) : response({ error: "private upstream diagnostic and credential" }, status);
  };
  try {
    const result = await handler(new Request("https://edge.example.com", { method: "POST", headers: { authorization: "Bearer user-test-token", "Content-Type": "application/json" }, body: JSON.stringify({ messages: [{ role: "user", content: "hello" }], ...payload }) }));
    return { status: result.status, body: await result.json(), calls, providerCalls };
  } finally { globalThis.fetch = original; }
}

Deno.test("01 discovery normalizes multiple models and preserves a dynamic catalogue", async () => {
  const x = await exercise({}, { action: "discover_models", provider_id: "a" });
  equal(x.body.discovered, 2);
  equal(x.calls.find(c => c.path.endsWith("ingest_ai_model_catalogue"))?.body.p_models.map((m: {slug: string}) => m.slug), ["one", "two"]);
});
Deno.test("02 disappeared models become stale and unavailable without deletion", async () => {
  const x = await exercise({}, { action: "discover_models", provider_id: "a" });
  equal(x.body.removed, 1);
  equal(x.calls.filter(c => c.path.endsWith("ingest_ai_model_catalogue")).length, 1);
});
Deno.test("03 preferred eligible healthy model is selected", async () => {
  const x = await exercise(); equal(x.body.model, "first"); equal(x.providerCalls, 1);
});
Deno.test("04 preferred 429 fails over to next eligible model", async () => {
  const x = await exercise({ status: [429, 200] }); equal(x.body.model, "second"); equal(x.body.failover, true);
});
Deno.test("05 timeout safely fails over", async () => {
  const x = await exercise({ timeout: true }); equal(x.body.model, "second");
});
Deno.test("06 model-specific upstream failure safely fails over", async () => {
  const x = await exercise({ status: [404, 200] }); equal(x.body.model, "second");
  equal(x.calls.find(c => c.path.endsWith("record_ai_model_outcome"))?.body.p_error_code, "provider_model_unavailable");
});
Deno.test("07 provider A fails and provider B succeeds", async () => {
  const x = await exercise({ status: [503, 503, 200] }); equal(x.body.provider, "b");
});
Deno.test("08 invalid A skips every remaining A model and healthy B stays available", async () => {
  const x = await exercise({ chain: [runtime(), runtime("a", "two"), runtime("a", "three"), runtime("a", "four"), runtime("a", "five"), runtime("b", "six")], status: [401, 200] });
  equal(x.providerCalls, 2); equal(x.body.provider, "b");
  equal(x.calls.find(c => c.path.endsWith("record_ai_provider_outcome"))?.body.p_error_code, "provider_unauthorized");
});
Deno.test("09 all providers fail with useful sanitized final error", async () => {
  const x = await exercise({ status: [503, 503, 503] }); equal(x.status, 503); equal(x.body.code, "provider_unavailable");
});
Deno.test("10 capability requirements reach the strict RPC and failure cannot downgrade", async () => {
  const x = await exercise({ chainFails: true }, { require_tools: true, require_structured: true, min_context: 32000 });
  equal(x.providerCalls, 0); equal(x.body.code, "routing_unavailable");
  const calls = x.calls.filter(c => c.path.includes("get_ai_runtime_chain")); equal(calls.length, 1);
  equal(calls[0].body.p_require_tools, true); equal(calls[0].body.p_min_context, 32000);
});
Deno.test("11 exhausted eligible pool makes no provider request during cooldown", async () => {
  const x = await exercise({ chain: [] }); equal(x.providerCalls, 0); equal(x.body.code, "no_eligible_model");
});
Deno.test("12 recovered eligible model is tried and records success", async () => {
  const x = await exercise({ chain: [runtime("b", "recovered")] }); equal(x.body.model, "recovered");
  equal(x.calls.find(c => c.path.endsWith("record_ai_model_outcome"))?.body.p_success, true);
});
Deno.test("13 attempts are bounded even with a large catalogue", async () => {
  const x = await exercise({ chain: Array.from({ length: 50 }, (_, i) => runtime(String(i), String(i))), status: Array(50).fill(429) }); equal(x.providerCalls, 5);
});
Deno.test("14 persistence failure after successful inference never invokes another model", async () => {
  const x = await exercise({ persistFails: true }); equal(x.providerCalls, 1); equal(x.status, 200); equal(x.body.reply, "Accepted response");
  equal(x.calls.filter(c => c.body?.status === "succeeded").length, 1);
});
Deno.test("15 telemetry contains only sanitized metadata and no secrets or upstream text", async () => {
  const x = await exercise({ status: [401, 200] });
  const text = JSON.stringify(x.calls.filter(c => c.path.includes("/rest/v1/")).map(c => c.body));
  equal(/test-only-credential|test-only-service|private upstream|Bearer/.test(text), false);
});
Deno.test("16 secrets never reach client responses, including failure responses", async () => {
  for (const status of [200, 401, 429, 500]) {
    const x = await exercise({ chain: [runtime()], status: [status] });
    equal(/test-only-credential|test-only-service|private upstream|api_key|Authorization/.test(JSON.stringify(x.body)), false);
  }
});
Deno.test("public discovery cannot clear rejected credentials", async () => {
  const x = await exercise({}, { action: "discover_models", provider_id: "a" });
  equal(x.calls.filter(c => c.path.endsWith("record_ai_provider_outcome")).length, 0);
});
Deno.test("explicit credential revalidation requires an authenticated model response", async () => {
  const x = await exercise({}, { action: "test_provider", provider_id: "a" });
  equal(x.providerCalls, 1); equal(x.calls.find(c => c.path.endsWith("record_ai_provider_outcome"))?.body.p_revalidated, true);
});
Deno.test("ordinary users cannot discover providers or use Admin AI", async () => {
  for (const payload of [{ action: "discover_models", provider_id: "a" }, { scope: "admin" }]) {
    const x = await exercise({ role: "user" }, payload); equal(x.status, 403); equal(x.providerCalls, 0);
  }
});
