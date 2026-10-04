import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const dbHeaders = { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" };
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, apikey, content-type" };

async function db(path: string, init: RequestInit = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { ...init, headers: { ...dbHeaders, ...(init.headers ?? {}) } });
  const text = await response.text();
  if (!response.ok) throw new Error(`database_${response.status}`);
  return text ? JSON.parse(text) : null;
}
const safeJson = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

/** Reject non-public HTTPS targets (SSRF defense in depth). */
function isSafePublicHttpsUrl(url: string): boolean {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }
  if (parsed.protocol !== "https:") return false;
  const host = parsed.hostname.toLowerCase();
  if (!host || host === "localhost" || host === "localhost.localdomain" || host === "0.0.0.0") return false;
  if (host === "metadata.google.internal" || host === "metadata") return false;
  if (host.endsWith(".localhost") || host.endsWith(".local")) return false;
  if (host === "::1" || host.startsWith("fe80:") || host.startsWith("fc") || host.startsWith("fd")) return false;
  const ipv4 = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (ipv4) {
    const a = Number(ipv4[1]), b = Number(ipv4[2]);
    if (a === 127) return false;
    if (a === 10) return false;
    if (a === 172 && b >= 16 && b <= 31) return false;
    if (a === 192 && b === 168) return false;
    if (a === 169 && b === 254) return false;
    if (a === 100 && b >= 64 && b <= 127) return false;
  }
  return true;
}

type Runtime = { provider_id:string; provider_slug:string; adapter:string; base_url:string; model_id:string; model_slug:string; max_output_tokens:number; api_key:string };

async function callProvider(runtime: Runtime, messages: Array<{role:string;content:string}>, signal: AbortSignal) {
  if (!isSafePublicHttpsUrl(runtime.base_url)) {
    throw new Error("provider_base_url_blocked");
  }
  if (runtime.adapter === "openai_compatible") {
    const response = await fetch(`${runtime.base_url}/chat/completions`, {
      method:"POST", signal, headers:{ Authorization:`Bearer ${runtime.api_key}`,"Content-Type":"application/json" },
      body:JSON.stringify({ model:runtime.model_slug,messages,max_tokens:runtime.max_output_tokens,temperature:0.2 })
    });
    if (!response.ok) throw new Error(`provider_http_${response.status}`);
    const data=await response.json();
    return { text:String(data?.choices?.[0]?.message?.content ?? ""), usage:data?.usage ?? {} };
  }
  if (runtime.adapter === "anthropic") {
    const response=await fetch(`${runtime.base_url}/v1/messages`,{
      method:"POST",signal,headers:{"x-api-key":runtime.api_key,"anthropic-version":"2023-06-01","Content-Type":"application/json"},
      body:JSON.stringify({model:runtime.model_slug,max_tokens:runtime.max_output_tokens,messages})
    });
    if (!response.ok) throw new Error(`provider_http_${response.status}`);
    const data=await response.json();
    return {text:String(data?.content?.[0]?.text ?? ""),usage:{prompt_tokens:data?.usage?.input_tokens,completion_tokens:data?.usage?.output_tokens}};
  }
  if (runtime.adapter === "gemini") {
    const contents=messages.map((m)=>({role:m.role==="assistant"?"model":"user",parts:[{text:m.content}]}));
    const response=await fetch(`${runtime.base_url}/v1beta/models/${encodeURIComponent(runtime.model_slug)}:generateContent?key=${encodeURIComponent(runtime.api_key)}`,{
      method:"POST",signal,headers:{"Content-Type":"application/json"},body:JSON.stringify({contents,generationConfig:{maxOutputTokens:runtime.max_output_tokens,temperature:0.2}})
    });
    if (!response.ok) throw new Error(`provider_http_${response.status}`);
    const data=await response.json();
    return {text:String(data?.candidates?.[0]?.content?.parts?.[0]?.text ?? ""),usage:{prompt_tokens:data?.usageMetadata?.promptTokenCount,completion_tokens:data?.usageMetadata?.candidatesTokenCount}};
  }
  throw new Error("unsupported_adapter");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok",{headers:cors});
  if (req.method !== "POST") return safeJson(405,{error:"method_not_allowed"});
  const authorization=req.headers.get("authorization") ?? "";
  const userResponse=await fetch(`${SUPABASE_URL}/auth/v1/user`,{headers:{apikey:SERVICE_KEY,Authorization:authorization}});
  if (!userResponse.ok) return safeJson(401,{error:"authentication_required"});
  const user=await userResponse.json();

  let payload: {messages?:Array<{role?:unknown;content?:unknown}>;session_id?:unknown};
  try { payload=await req.json(); } catch { return safeJson(400,{error:"invalid_json"}); }
  const messages=(payload.messages ?? []).slice(-40).map((m)=>({role:m.role==="assistant"?"assistant":"user",content:String(m.content ?? "").slice(0,12000)})).filter((m)=>m.content.length>0);
  if (!messages.length) return safeJson(400,{error:"messages_required"});

  const profile=await db(`profiles?select=role&id=eq.${encodeURIComponent(user.id)}&limit=1`);
  const role=profile?.[0]?.role ?? "user";
  const limits=await db(`ai_usage_limits?select=daily_requests,daily_output_tokens&role=eq.${encodeURIComponent(role)}&limit=1`);
  const day=new Date(); day.setUTCHours(0,0,0,0);
  const recent=await db(`ai_requests?select=id,output_tokens&user_id=eq.${encodeURIComponent(user.id)}&created_at=gte.${encodeURIComponent(day.toISOString())}`);
  const usedTokens=(recent ?? []).reduce((sum:number,row:{output_tokens?:number})=>sum+(row.output_tokens ?? 0),0);
  if ((recent?.length ?? 0) >= (limits?.[0]?.daily_requests ?? 50) || usedTokens >= (limits?.[0]?.daily_output_tokens ?? 100000)) {
    return safeJson(429,{error:"daily_limit_reached"});
  }

  const created=await db("ai_requests?select=id",{method:"POST",headers:{Prefer:"return=representation"},body:JSON.stringify({
    user_id:user.id,session_id:typeof payload.session_id==="string"?payload.session_id:null,capability:"chat",status:"running"
  })});
  const requestId=created[0].id;
  const chain:Runtime[]=await db("rpc/get_ai_runtime_chain",{method:"POST",body:JSON.stringify({p_capability:"chat"})});
  if (!chain.length) {
    await db(`ai_requests?id=eq.${requestId}`,{method:"PATCH",body:JSON.stringify({status:"failed",safe_error_code:"no_provider_configured",finished_at:new Date().toISOString()})});
    return safeJson(503,{error:"ai_temporarily_unavailable",code:"no_provider_configured"});
  }

  let lastCode="provider_unavailable";
  const started=Date.now();
  for (const [index,runtime] of chain.slice(0,3).entries()) {
    try {
      const result=await callProvider(runtime,messages,AbortSignal.timeout(25000));
      if (!result.text) throw new Error("provider_empty_response");
      await db(`ai_provider_health?provider_id=eq.${runtime.provider_id}`,{method:"PATCH",body:JSON.stringify({
        status:"healthy",consecutive_failures:0,last_success_at:new Date().toISOString(),cooldown_until:null,safe_error_code:null,updated_at:new Date().toISOString()
      })});
      await db(`ai_requests?id=eq.${requestId}`,{method:"PATCH",body:JSON.stringify({
        status:"succeeded",provider_id:runtime.provider_id,model_id:runtime.model_id,attempt_count:index+1,
        input_tokens:result.usage?.prompt_tokens ?? null,output_tokens:result.usage?.completion_tokens ?? null,
        latency_ms:Date.now()-started,finished_at:new Date().toISOString()
      })});
      return safeJson(200,{reply:result.text,provider:runtime.provider_slug,model:runtime.model_slug,request_id:requestId});
    } catch (error) {
      lastCode=error instanceof DOMException && error.name==="TimeoutError"?"provider_timeout":
        String(error instanceof Error?error.message:error).replace(/[^a-zA-Z0-9_]/g,"_").slice(0,80);
      await db(`ai_provider_health?provider_id=eq.${runtime.provider_id}`,{method:"PATCH",body:JSON.stringify({
        status:"degraded",last_failure_at:new Date().toISOString(),safe_error_code:lastCode,updated_at:new Date().toISOString()
      })});
    }
  }
  await db(`ai_requests?id=eq.${requestId}`,{method:"PATCH",body:JSON.stringify({
    status:"failed",attempt_count:Math.min(chain.length,3),safe_error_code:lastCode,latency_ms:Date.now()-started,finished_at:new Date().toISOString()
  })});
  return safeJson(503,{error:"ai_temporarily_unavailable",code:lastCode,request_id:requestId});
});
