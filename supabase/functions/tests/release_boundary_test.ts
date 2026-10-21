Deno.env.set("SUPABASE_URL", "https://db.example.com");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "synthetic-service-canary");
const { discover, ProviderError } = await import("../ai-orchestrator/handler_providers.ts");
const { parseProviderResponse } = await import("../ai-orchestrator/provider_response.ts");
function assert(value: unknown): asserts value {
  if (!value) throw new Error("Boundary regression failed");
}
async function catalogue(adapter: string, pages: unknown[], baseUrl = "https://provider.example.com") {
  const original = globalThis.fetch;
  const urls: string[] = [];
  globalThis.fetch = (input) => {
    urls.push(String(input));
    return Promise.resolve(Response.json(pages[urls.length - 1]));
  };
  try {
    const models = await discover({
      adapter, provider_id: "synthetic", provider_slug: "synthetic",
      base_url: baseUrl, api_key: "synthetic-provider-canary",
      request_timeout_seconds: 5, credential_version: 1,
    });
    return { models, urls };
  } finally { globalThis.fetch = original; }
}
Deno.test("catalogue: malformed envelopes and rows fail with a fixed provider error", async () => {
  for (const payload of [null, [], {data:[null]}, {data:[[]]}, {models:["private diagnostic"]}]) {
    let failed = false;
    try { await catalogue("openai_compatible", [payload]); }
    catch (error) { failed = error instanceof ProviderError && error.code === "provider_malformed_response"; }
    assert(failed);
  }
});
Deno.test("catalogue: malformed or missing continuation never approves an incomplete page", async () => {
  for (const [adapter, payload] of [
    ["anthropic", {data:[{id:"synthetic"}],has_more:true}],
    ["anthropic", {data:[{id:"synthetic"}],has_more:"true",last_id:"x"}],
    ["anthropic", {data:[{id:"synthetic"}],has_more:true,last_id:{private:"canary"}}],
    ["gemini", {models:[{name:"models/synthetic"}],nextPageToken:42}],
    ["gemini", {models:[],nextPageToken:"x".repeat(2049)}],
  ] as const) {
    let failed = false;
    try { await catalogue(adapter, [payload]); }
    catch (error) { failed = error instanceof ProviderError && error.code === "provider_malformed_response"; }
    assert(failed);
  }
});
Deno.test("catalogue: valid continuation stays on provider origin and retains both pages", async () => {
  const x=await catalogue("gemini", [
    {models:[{name:"models/first",inputTokenLimit:4096}],nextPageToken:"synthetic token"},
    {models:[{name:"models/second"}]},
  ]);
  assert(x.models.length===2 && x.models[0].slug==="first" && x.models[1].slug==="second");
  assert(x.urls.every(url=>new URL(url).origin==="https://provider.example.com"));
  assert(new URL(x.urls[1]).searchParams.get("pageToken")==="synthetic token");
  const last=await catalogue("anthropic",[{data:[{id:"synthetic"}],has_more:false}]);
  assert(last.models.length===1 && last.urls.length===1);
});
Deno.test("provider text: control-character rejection preserves tabs, lines and Unicode", () => {
  for(let code=0;code<32;code++) {
    const text="a"+String.fromCharCode(code)+"b";
    let accepted=false;
    try { accepted=parseProviderResponse("openai_compatible",{choices:[{message:{content:text}}]}).text===text; }
    catch(error) { assert(error instanceof ProviderError && error.code==="provider_malformed_response"); }
    assert(accepted===[9,10,13].includes(code));
  }
  assert(parseProviderResponse("openai_compatible",{choices:[{message:{content:"\u0631\u0627\u062f"}}]}).text==="\u0631\u0627\u062f");
});

Deno.test("catalogue: malformed pricing and capacity cannot become free or discovered defaults", async () => {
  for (const bad of [null, false, true, "", " ", [], [0], {}, "NaN", "Infinity", "-1", "1e-999"]) {
    const x = await catalogue("openai_compatible", [{data:[{
      id:"synthetic",context_length:bad,pricing:{prompt:bad},supported_parameters:[{}],
    }]}], "https://openrouter.ai/api/v1");
    const model=x.models[0];
    assert(model.context_window===null && model.cost_input_per_million===null);
    assert(model.cost_source==="unknown" && model.capability_source==="unknown");
  }
  for (const price of [0,"0","0.000001"]) {
    const x=await catalogue("openai_compatible",[{data:[{
      id:"synthetic",context_length:4096,pricing:{prompt:price},supported_parameters:["tools"],
    }]}],"https://openrouter.ai/api/v1");
    assert(x.models[0].cost_input_per_million===Number(price)*1000000);
    assert(x.models[0].cost_source==="discovered" && x.models[0].context_window===4096);
  }
});
