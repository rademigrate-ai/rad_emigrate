import { corsHeaders } from "../_shared/cors.ts";

export const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
export const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
export const dbHeaders = { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" };
export const cors = corsHeaders;

export async function db(path: string, init: RequestInit = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { ...init, headers: { ...dbHeaders, ...(init.headers ?? {}) } });
  const text = await response.text();
  if (!response.ok) throw new Error(`database_${response.status}`);
  return text ? JSON.parse(text) : null;
}
export const safeJson = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

function isSafePublicHttpsUrl(value: string): boolean {
  let parsed: URL;
  try { parsed = new URL(value); } catch { return false; }
  if (parsed.protocol !== "https:" || parsed.username || parsed.password) return false;
  const host = parsed.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (!host || ["localhost", "localhost.localdomain", "0.0.0.0", "metadata", "metadata.google.internal"].includes(host)) return false;
  if (host.endsWith(".localhost") || host.endsWith(".local") || host === "::1" || /^(fe80:|fc|fd)/.test(host)) return false;
  const match = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (match) {
    const octets = match.slice(1).map(Number);
    if (octets.some((part) => part > 255)) return false;
    const [a, b] = octets;
    if (a === 0 || a === 10 || a === 127 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127) || a >= 224) return false;
  }
  return true;
}

export class ProviderError extends Error {
  constructor(readonly code: string, readonly status = 502) { super(code); }
}
export type Runtime = {
  provider_id: string; provider_slug: string; adapter: string; base_url: string;
  model_id: string; model_slug: string; max_output_tokens: number;
  request_timeout_seconds: number; max_retries: number; api_key: string;
  routing_score?: number; capability_source?: string; credential_version: number;
};
export type ProviderRuntime = Pick<Runtime, "provider_id" | "provider_slug" | "adapter" | "base_url" | "request_timeout_seconds" | "api_key" | "credential_version">;

export type AttemptLog = {
  attempt: number;
  provider: string;
  model: string;
  result: "success" | "failure";
  code?: string;
  latency_ms?: number;
};

function providerHeaders(runtime: ProviderRuntime): Record<string, string> {
  if (runtime.adapter === "gemini") return { "x-goog-api-key": runtime.api_key, "Content-Type": "application/json" };
  return runtime.adapter === "anthropic"
    ? { "x-api-key": runtime.api_key, "anthropic-version": "2023-06-01", "Content-Type": "application/json" }
    : { Authorization: `Bearer ${runtime.api_key}`, "Content-Type": "application/json" };
}

async function providerFetch(url: string, init: RequestInit, timeoutSeconds: number) {
  if (!isSafePublicHttpsUrl(url)) throw new ProviderError("unsafe_base_url", 400);
  let response: Response;
  try {
    response = await fetch(url, { ...init, redirect: "manual", signal: AbortSignal.timeout(Math.min(Math.max(timeoutSeconds, 5), 120) * 1000) });
  } catch (error) {
    if (error instanceof DOMException && error.name === "TimeoutError") throw new ProviderError("provider_timeout", 504);
    throw new ProviderError("provider_unreachable");
  }
  if (response.status >= 300 && response.status < 400) throw new ProviderError("unsafe_redirect", 400);
  if (response.status === 401 || response.status === 403) throw new ProviderError("provider_unauthorized", 401);
  if (response.status === 404) throw new ProviderError("provider_model_unavailable", 404);
  if (response.status === 429) throw new ProviderError("provider_rate_limited", 429);
  if (response.status >= 500) throw new ProviderError("provider_unavailable", 503);
  if (!response.ok) throw new ProviderError("provider_invalid_request");
  return response;
}

type DiscoveredModel = {
  slug: string; capability: string; context_window: number | null;
  supports_tools: boolean; supports_structured_output: boolean; capability_source: string;
  cost_input_per_million: number | null; cost_source: string;
};

export async function discover(runtime: ProviderRuntime): Promise<DiscoveredModel[]> {
  const url = runtime.adapter === "gemini"
    ? `${runtime.base_url}/v1beta/models`
    : `${runtime.base_url}${runtime.adapter === "anthropic" ? "/v1/models" : "/models"}`;
  const rows: Array<Record<string, any>> = [];
  let nextUrl = url;
  for (let page = 0; page < 10; page++) {
    const response = await providerFetch(nextUrl, { headers: providerHeaders(runtime) }, Math.min(runtime.request_timeout_seconds, 10));
    const data = await response.json().catch(() => { throw new ProviderError("provider_malformed_response"); });
    const current = Array.isArray(data?.data) ? data.data : Array.isArray(data?.models) ? data.models : null;
    if (!current || rows.length + current.length > 5000) throw new ProviderError("provider_malformed_response");
    rows.push(...current);
    const token = runtime.adapter === "gemini" ? data.nextPageToken : runtime.adapter === "anthropic" && data.has_more ? data.last_id : null;
    if (!token) break;
    if (page === 9) throw new ProviderError("catalogue_incomplete");
    const next = new URL(url);
    next.searchParams.set(runtime.adapter === "gemini" ? "pageToken" : "after_id", String(token));
    nextUrl = next.toString();
  }
  const catalogue = new Map<string, DiscoveredModel>();
  for (const item of rows) {
    const slug = String(item.id ?? item.name ?? "").replace(/^models\//, "").trim();
    if (!slug || slug.length > 300 || !/^[a-zA-Z0-9_./:@+-]+$/.test(slug)) continue;
    const context = Number(item.context_length ?? item.inputTokenLimit);
    const parameters = Array.isArray(item.supported_parameters) ? item.supported_parameters : null;
    const price = new URL(runtime.base_url).hostname === "openrouter.ai" && item.pricing?.prompt != null
      ? Number(item.pricing.prompt) * 1000000 : NaN;
    const methods = Array.isArray(item.supportedGenerationMethods) ? item.supportedGenerationMethods : null;
    const capability = methods?.includes("embedContent") && !methods.includes("generateContent") ? "embedding" : "chat";
    catalogue.set(slug, {
      slug, capability,
      context_window: Number.isSafeInteger(context) && context > 0 ? context : null,
      supports_tools: parameters?.includes("tools") ?? false,
      supports_structured_output: parameters?.includes("structured_outputs") ?? false,
      capability_source: parameters || Number.isSafeInteger(context) && context > 0 ? "discovered" : "unknown",
      cost_input_per_million: Number.isFinite(price) && price >= 0 && price < 100000 ? price : null,
      cost_source: Number.isFinite(price) && price >= 0 && price < 100000 ? "discovered" : "unknown",
    });
  }
  return [...catalogue.values()].sort((a, b) => a.slug.localeCompare(b.slug));
}

export async function callProvider(runtime: Runtime, messages: Array<{ role: string; content: string }>) {
  if (runtime.adapter === "openai_compatible") {
    const response = await providerFetch(`${runtime.base_url}/chat/completions`, {
      method: "POST", headers: providerHeaders(runtime),
      body: JSON.stringify({ model: runtime.model_slug, messages, max_tokens: runtime.max_output_tokens, temperature: 0.2 }),
    }, runtime.request_timeout_seconds);
    const data = await response.json().catch(() => { throw new ProviderError("provider_malformed_response"); });
    return { text: String(data?.choices?.[0]?.message?.content ?? ""), usage: data?.usage ?? {} };
  }
  if (runtime.adapter === "anthropic") {
    const response = await providerFetch(`${runtime.base_url}/v1/messages`, {
      method: "POST", headers: providerHeaders(runtime),
      body: JSON.stringify({ model: runtime.model_slug, max_tokens: runtime.max_output_tokens, messages }),
    }, runtime.request_timeout_seconds);
    const data = await response.json().catch(() => { throw new ProviderError("provider_malformed_response"); });
    return {
      text: String(data?.content?.[0]?.text ?? ""),
      usage: { prompt_tokens: data?.usage?.input_tokens, completion_tokens: data?.usage?.output_tokens },
    };
  }
  if (runtime.adapter === "gemini") {
    const contents = messages.map((message) => ({
      role: message.role === "assistant" ? "model" : "user",
      parts: [{ text: message.content }],
    }));
    const url = `${runtime.base_url}/v1beta/models/${encodeURIComponent(runtime.model_slug)}:generateContent`;
    const response = await providerFetch(url, {
      method: "POST",
      headers: providerHeaders(runtime),
      body: JSON.stringify({ contents, generationConfig: { maxOutputTokens: runtime.max_output_tokens, temperature: 0.2 } }),
    }, runtime.request_timeout_seconds);
    const data = await response.json().catch(() => { throw new ProviderError("provider_malformed_response"); });
    return {
      text: String(data?.candidates?.[0]?.content?.parts?.[0]?.text ?? ""),
      usage: {
        prompt_tokens: data?.usageMetadata?.promptTokenCount,
        completion_tokens: data?.usageMetadata?.candidatesTokenCount,
      },
    };
  }
  throw new ProviderError("unsupported_adapter", 400);
}

export async function providerRuntime(providerId: string): Promise<ProviderRuntime> {
  const rows = await db("rpc/get_ai_provider_runtime_versioned", { method: "POST", body: JSON.stringify({ p_provider_id: providerId }) });
  if (!rows?.length) throw new ProviderError("provider_not_configured", 404);
  return rows[0];
}

export async function recordHealth(runtime: ProviderRuntime, code?: string, revalidated = false) {
  await db("rpc/record_ai_provider_outcome", {
    method: "POST",
    body: JSON.stringify({
      p_provider_id: runtime.provider_id,
      p_credential_version: runtime.credential_version,
      p_error_code: code ?? null,
      p_revalidated: revalidated,
    }),
  });
}

export async function recordModelOutcome(modelId: string, success: boolean, latencyMs?: number, errorCode?: string) {
  try {
    await db("rpc/record_ai_model_outcome", {
      method: "POST",
      body: JSON.stringify({
        p_model_id: modelId,
        p_success: success,
        p_latency_ms: latencyMs ?? null,
        p_error_code: errorCode ?? null,
      }),
    });
  } catch {
    // best-effort; never fail the user path on telemetry
  }
}
