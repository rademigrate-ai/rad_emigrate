import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { researchCorsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const headers = { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" };
const cors = researchCorsHeaders;
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

async function rest(path: string, init: RequestInit = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { ...init, headers: { ...headers, ...(init.headers ?? {}) } });
  const text = await response.text();
  if (!response.ok) throw new Error(`database_${response.status}`);
  return text ? JSON.parse(text) : null;
}

async function digest(value: string) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function normalize(html: string) {
  return html.replace(/<script[\s\S]*?<\/script>/gi, " ").replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<!--([\s\S]*?)-->/g, " ").replace(/<[^>]+>/g, " ").replace(/&nbsp;|&#160;/gi, " ")
    .replace(/&amp;/gi, "&").replace(/\s+/g, " ").trim().slice(0, 100000);
}

function safeUrl(value: string, allowedHost: string) {
  let url: URL;
  try { url = new URL(value); } catch { return false; }
  const host = url.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (url.protocol !== "https:" || url.username || url.password || host !== allowedHost.toLowerCase()) return false;
  if (["localhost", "0.0.0.0", "metadata", "metadata.google.internal"].includes(host) || host.endsWith(".local") || host === "::1" || /^(fe80:|fc|fd)/.test(host)) return false;
  const ip = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (ip) {
    const [a, b] = ip.slice(1).map(Number);
    if (a === 0 || a === 10 || a === 127 || a >= 224 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127)) return false;
  }
  return true;
}

async function fetchSource(start: string, allowedHost: string, timeout: number) {
  let current = start;
  for (let redirects = 0; redirects <= 3; redirects++) {
    if (!safeUrl(current, allowedHost)) throw new Error("unsafe_source_url");
    const response = await fetch(current, { redirect: "manual", signal: AbortSignal.timeout(timeout), headers: { "User-Agent": "RAD-Knowledge-Sync/1.0 (+https://radvisa.com)", Accept: "text/html,text/plain;q=0.9" } });
    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get("location");
      if (!location || redirects === 3) throw new Error("unsafe_source_redirect");
      current = new URL(location, current).toString();
      continue;
    }
    if (!response.ok) throw new Error(`source_http_${response.status}`);
    const length = Number(response.headers.get("content-length") ?? 0);
    if (length > 1_000_000) throw new Error("source_too_large");
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.byteLength > 1_000_000) throw new Error("source_too_large");
    return { text: new TextDecoder().decode(bytes), status: response.status, finalUrl: current };
  }
  throw new Error("unsafe_source_redirect");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const config = await rest("research_worker_config?select=invocation_token,max_sources_per_run,request_timeout_ms&singleton=eq.true");
    const worker = config?.[0];
    if (!worker) return json({ error: "forbidden" }, 403);
    let authorized = req.headers.get("x-rad-research-token") === worker.invocation_token;
    if (!authorized) {
      const authorization = req.headers.get("authorization") ?? "";
      const userResponse = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: SERVICE_KEY, Authorization: authorization } });
      if (userResponse.ok) {
        const user = await userResponse.json();
        const profiles = await rest(`profiles?select=role&id=eq.${encodeURIComponent(user.id)}&limit=1`);
        authorized = ["admin", "super_admin"].includes(profiles?.[0]?.role);
      }
    }
    if (!authorized) return json({ error: "forbidden" }, 403);
    const jobs = await rest("research_jobs?select=*&status=eq.queued&next_attempt_at=lte.now()&order=created_at.asc&limit=1");
    const job = jobs?.[0];
    if (!job) return json({ processed: 0 });
    const claimed = await rest(`research_jobs?id=eq.${job.id}&status=eq.queued&select=id`, { method: "PATCH", headers: { Prefer: "return=representation" }, body: JSON.stringify({ status: "running", started_at: new Date().toISOString(), attempts: job.attempts + 1 }) });
    if (!claimed?.length) return json({ processed: 0 });
    const sources = await rest(`research_sources?select=*&enabled=eq.true&order=created_at.asc&limit=${worker.max_sources_per_run}`);
    let changed = 0;
    let failed = 0;
    for (const source of sources ?? []) {
      try {
        const fetched = await fetchSource(source.base_url, source.allowed_host, worker.request_timeout_ms);
        const text = normalize(fetched.text);
        if (!text) throw new Error("source_empty");
        const hash = await digest(text);
        const documents = await rest(`source_documents?select=id,language_code&canonical_url=eq.${encodeURIComponent(source.base_url)}&limit=1`);
        let documentId = documents?.[0]?.id;
        const language = documents?.[0]?.language_code ?? (source.base_url.includes("/fa") || source.allowed_host.endsWith(".ir") ? "fa" : "en");
        if (!documentId) {
          const created = await rest("source_documents", { method: "POST", headers: { Prefer: "return=representation" }, body: JSON.stringify({ canonical_url: source.base_url, source_authority: source.authority, title: source.display_name || source.allowed_host, language_code: language }) });
          documentId = created[0].id;
        }
        const prior = await rest(`source_snapshots?select=id,content_hash&document_id=eq.${documentId}&order=fetched_at.desc&limit=1`);
        if (prior?.[0]?.content_hash !== hash) {
          const snapshots = await rest("source_snapshots", { method: "POST", headers: { Prefer: "return=representation" }, body: JSON.stringify({ document_id: documentId, content_hash: hash, normalized_text: text, http_status: fetched.status, metadata: { final_url: fetched.finalUrl, trust_class: source.trust_class, source_type: source.source_type } }) });
          const findingType = prior?.length ? "changed" : "new";
          const summary = `${findingType === "new" ? "New content" : "Material content change"} detected at ${source.base_url}. Evidence is preserved for admin review.`;
          const findings = await rest("research_findings?select=id", { method: "POST", headers: { Prefer: "return=representation" }, body: JSON.stringify({ research_job_id: job.id, snapshot_id: snapshots[0].id, finding_type: findingType, summary }) });
          await rest("rpc/create_research_review_candidate", { method: "POST", body: JSON.stringify({ p_job_id: job.id, p_finding_id: findings[0].id, p_title: `${source.display_name || source.allowed_host}: ${findingType}`, p_summary: summary, p_language_code: language }) });
          changed++;
        }
        await rest(`source_documents?id=eq.${documentId}`, { method: "PATCH", body: JSON.stringify({ last_seen_at: new Date().toISOString(), removed_at: null }) });
        await rest(`research_sources?id=eq.${source.id}`, { method: "PATCH", body: JSON.stringify({ last_attempt_at: new Date().toISOString(), last_success_at: new Date().toISOString(), last_error_code: null }) });
      } catch (error) {
        failed++;
        const code = String(error instanceof Error ? error.message : "source_fetch_failed").replace(/[^a-zA-Z0-9_]/g, "_").slice(0, 80);
        await rest(`research_sources?id=eq.${source.id}`, { method: "PATCH", body: JSON.stringify({ last_attempt_at: new Date().toISOString(), last_error_code: code }) }).catch(() => undefined);
      }
    }
    const status = failed > 0 && changed === 0 ? "failed" : "succeeded";
    await rest(`research_jobs?id=eq.${job.id}`, { method: "PATCH", body: JSON.stringify({ status, safe_error: failed ? `${failed}_source_failures` : null, error_code: failed ? "source_failures" : null, finished_at: new Date().toISOString() }) });
    return json({ processed: 1, changed, failed });
  } catch (error) {
    const code = String(error instanceof Error ? error.message : "research_sync_failed").replace(/[^a-zA-Z0-9_]/g, "_").slice(0, 80);
    return json({ error: code }, 500);
  }
});
