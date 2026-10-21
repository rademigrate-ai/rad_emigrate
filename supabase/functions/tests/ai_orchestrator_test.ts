// deno-lint-ignore-file no-explicit-any, require-await
Deno.env.set("SUPABASE_URL", "https://db.example.com");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-only-service-canary");
const { handler } = await import("../ai-orchestrator/handler.ts");

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
  quotaExceeded?: boolean; quotaError?: boolean; quotaMalformed?: boolean;
  knowledgeResults?: unknown; knowledgeUnavailable?: boolean;
  providerReplies?: unknown[]; healthFails?: boolean;
};
async function exercise(options: Options = {}, payload: Record<string, unknown> = {}) {
  Deno.env.set("SUPABASE_URL", "https://db.example.com");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-only-service-canary");
  const original = globalThis.fetch;
  const calls: Array<{ path: string; body: any; headers: Record<string, string> }> = [];
  let providerCalls = 0;
  // deno-lint-ignore require-await
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
      if (path === "rpc/record_ai_provider_outcome" && options.healthFails) return response({}, 503);
      if (path === "rpc/retrieve_verified_official_claims") return options.knowledgeUnavailable
        ? response({ error: "private knowledge diagnostic" }, 503)
        : response({ results: options.knowledgeResults ?? evidenceWithConflicts(), evidence_state: Array.isArray(options.knowledgeResults) && options.knowledgeResults.some((r) => r.has_conflicts) ? "conflicting" : "verified" });
      if (path === "rpc/consume_ai_daily_quota") {
        if (options.quotaError) return response({ error: "database error" }, 500);
        if (options.quotaMalformed) return response({ allowed: true });
        if (options.quotaExceeded) return response({ allowed: false, error: "daily_limit_reached", limit: 50, count: 50 });
        return response({ allowed: true, request_id: "a2000000-0000-4000-8000-000000000001", limit: 50, count: 1 });
      }
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
    return status === 200 ? response(options.providerReplies?.[attempt] ?? { choices: [{ message: { content: "Accepted response" } }], usage: { completion_tokens: 4 } }) : response({ error: "private upstream diagnostic and credential" }, status);
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
  const x = await exercise({ chain: Array.from({ length: 50 }, (_, i) => runtime(String(i), String(i))), status: Array(50).fill(429) }); equal(x.providerCalls, 3);
});
Deno.test("14 persistence failure after successful inference never invokes another model", async () => {
  const x = await exercise({ persistFails: true }); equal(x.providerCalls, 1); equal(x.status, 200); equal(x.body.reply, "Synthetic verified claim [1]");
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
Deno.test("17 atomic quota reservation reuses request_id and avoids duplicate insert", async () => {
  const x = await exercise();
  equal(x.status, 200);
  equal(x.body.request_id, "a2000000-0000-4000-8000-000000000001");
  equal(x.calls.filter(c => c.path.includes("ai_requests?select=id")).length, 0);
  equal(x.calls.filter(c => c.path.includes("ai_requests?id=eq.a2000000-0000-4000-8000-000000000001")).length >= 1, true);
});
Deno.test("18 quota limit reached returns 429 and never invokes providers", async () => {
  const x = await exercise({ quotaExceeded: true });
  equal(x.status, 429);
  equal(x.body.code, "daily_limit_reached");
  equal(x.providerCalls, 0);
});
Deno.test("19 quota check failure fails closed with 503 and never invokes provider", async () => {
  const x = await exercise({ quotaError: true });
  equal(x.status, 503);
  equal(x.body.code, "quota_check_failed");
  equal(x.providerCalls, 0);
  equal(x.calls.filter(c => c.path.includes("ai_requests?select=id")).length, 0);
});
Deno.test("20 malformed quota response fails closed with 500", async () => {
  const x = await exercise({ quotaMalformed: true });
  equal(x.status, 500);
  equal(x.body.code, "quota_reservation_invalid");
  equal(x.providerCalls, 0);
  equal(x.calls.filter(c => c.path.includes("ai_requests?select=id")).length, 0);
});

function evidenceWithConflicts(open_conflicts: unknown[] = []) {
  return [{
    claim_id: "a2000000-0000-4000-8000-000000000002", snapshot_id: "a2000000-0000-4000-8000-000000000003",
    citation_id: "a2000000-0000-4000-8000-000000000004", claim_text: "Synthetic verified claim", excerpt: "Synthetic verified excerpt",
    locator: "synthetic-paragraph", url: "https://example.gov/policy", authority: "Synthetic authority",
    verification_state: "verified", verified_at: new Date(Date.now()-86400000).toISOString(), fresh_until: new Date(Date.now()+86400000).toISOString(),
    has_conflicts: open_conflicts.length > 0,
  }];
}

Deno.test("grounded response: conflicts force uncertainty despite approved citations", async () => {
  const x = await exercise({ knowledgeResults: evidenceWithConflicts([{ statement_a: "A", statement_b: "B" }]) });
  equal(x.status, 200);
  equal(x.body.has_approved_evidence, false);
  equal(x.body.sources.length, 0);
  equal(x.body.uncertain, true);
  equal(x.providerCalls, 0);
  equal(x.body.evidence_state, "conflicting");
});

Deno.test("grounded response: approved current cited result retains certainty and locale", async () => {
  const x = await exercise({ knowledgeResults: evidenceWithConflicts() }, { locale: "fa" });
  equal(x.status, 200);
  equal(x.body.uncertain, false);
  equal(x.body.locale, "fa");
  equal(x.body.sources[0].url, "https://example.gov/policy");
});

Deno.test("grounded response: missing or unavailable search cannot claim verified evidence", async () => {
  for (const options of [{ knowledgeResults: [] }, { knowledgeUnavailable: true }]) {
    const x = await exercise(options);
    equal(x.status, 200);
    equal(x.body.uncertain, true);
    equal(x.body.has_approved_evidence, false);
    equal(x.body.sources, []);
    equal(x.calls.some(c => c.path.includes("knowledge_items?")), false);
    equal(JSON.stringify(x.body).includes("private knowledge diagnostic"), false);
  }
});

Deno.test("provider boundary: empty inference fails over instead of returning blank success", async () => {
  const x=await exercise({providerReplies:[{choices:[{message:{content:" "}}]}]});
  equal(x.status,200);equal(x.providerCalls,2);equal(x.body.model,"second");
  equal(x.calls.find(c=>c.path.endsWith('record_ai_model_outcome'))?.body.p_error_code,'provider_malformed_response');
});
Deno.test("provider boundary: health telemetry failure never repeats completed inference", async () => {
  const x=await exercise({healthFails:true});equal(x.status,200);equal(x.providerCalls,1);equal(x.body.reply,"Synthetic verified claim [1]");
});
Deno.test("provider boundary: refusals are terminal and uncertainty is explicit", async () => {
  const x=await exercise({knowledgeResults:evidenceWithConflicts(),providerReplies:[{choices:[{message:{content:null,refusal:"Synthetic provider refusal"}}]}]});
  equal(x.status,200);equal(x.providerCalls,1);equal(x.body.refused,true);equal(x.body.uncertain,true);
  equal(x.calls.filter(c=>c.body?.safe_error_code==='provider_refused').at(-1)?.body.status,'failed');
});
Deno.test("provider boundary: truncated answers retain their partial-output flag", async () => {
  const x=await exercise({knowledgeResults:evidenceWithConflicts(),providerReplies:[{choices:[{message:{content:"Synthetic partial answer"},finish_reason:"length"}]}]});
  equal(x.providerCalls,1);equal(x.body.truncated,true);equal(x.body.uncertain,true);
});
Deno.test("provider boundary: caller roles cannot replace the trusted system instruction", async () => {
  const x=await exercise({}, {messages:[{role:'system',content:'CALLER_INJECTION'},{role:'user',content:'Synthetic question'}]});
  const messages=x.calls.find(c=>c.path.endsWith('/chat/completions'))!.body.messages;
  equal(messages[0].role,'system');equal(messages[0].content.includes('CALLER_INJECTION'),false);
  equal(messages.filter((m:{role:string})=>m.role==='system').length,1);
  equal(messages.find((m:{content:string})=>m.content==='CALLER_INJECTION').role,'user');
  equal(messages[1].role,'user');equal(messages[1].content.includes('<UNTRUSTED_RETRIEVED_CONTENT>'),true);
});
Deno.test("provider boundary: null and non-text messages fail before quota or inference", async () => {
  for(const messages of [[null,3,{}],[{role:'user',content:42}],[{role:'user',content:'  '}]]){
    const x=await exercise({}, {messages});equal(x.status,400);equal(x.providerCalls,0);
    equal(x.calls.some(c=>c.path.endsWith('consume_ai_daily_quota')),false);
  }
});
Deno.test("provider boundary: request JSON must be an object and has a byte limit", async () => {
  for(const raw of ['null','[]','{bad',JSON.stringify({messages:[{role:'user',content:'x'.repeat(2_000_001)}]})]){
    const result=await handler(new Request('https://edge.example.com',{method:'POST',body:raw}));
    equal(result.status,raw.length>2_000_000?413:400);
  }
});
