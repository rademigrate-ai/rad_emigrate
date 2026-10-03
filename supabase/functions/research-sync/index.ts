import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const headers = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
};

async function rest(path: string, init: RequestInit = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: { ...headers, ...(init.headers ?? {}) },
  });
  if (!response.ok) throw new Error(`database_${response.status}`);
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

async function digest(value: string) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function normalize(html: string) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 100000);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  try {
    const config = await rest("research_worker_config?select=invocation_token,max_sources_per_run,request_timeout_ms&singleton=eq.true");
    const worker = config?.[0];
    if (!worker || req.headers.get("x-rad-research-token") !== worker.invocation_token) {
      return new Response("forbidden", { status: 403 });
    }
    const jobs = await rest("research_jobs?select=*&status=eq.queued&next_attempt_at=lte.now()&order=created_at.asc&limit=1");
    const job = jobs?.[0];
    if (!job) return Response.json({ processed: 0 });
    await rest(`research_jobs?id=eq.${job.id}&status=eq.queued`, {
      method: "PATCH",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ status: "running", started_at: new Date().toISOString(), attempts: job.attempts + 1 }),
    });
    const sources = await rest(`research_sources?select=*&enabled=eq.true&order=created_at.asc&limit=${worker.max_sources_per_run}`);
    let changed = 0;
    for (const source of sources) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), worker.request_timeout_ms);
      try {
        const response = await fetch(source.base_url, {
          signal: controller.signal,
          headers: { "User-Agent": "RAD-Knowledge-Sync/1.0 (+https://radvisa.com)" },
        });
        const html = await response.text();
        const text = normalize(html);
        const hash = await digest(text);
        const docs = await rest(`source_documents?select=id&canonical_url=eq.${encodeURIComponent(source.base_url)}`);
        let documentId = docs?.[0]?.id;
        if (!documentId) {
          const created = await rest("source_documents", {
            method: "POST",
            headers: { Prefer: "return=representation" },
            body: JSON.stringify({
              canonical_url: source.base_url,
              source_authority: source.authority,
              title: source.allowed_host,
              language_code: "fa",
            }),
          });
          documentId = created[0].id;
        }
        const prior = await rest(`source_snapshots?select=id&document_id=eq.${documentId}&content_hash=eq.${hash}`);
        if (!prior?.length) {
          const snapshots = await rest("source_snapshots", {
            method: "POST",
            headers: { Prefer: "return=representation" },
            body: JSON.stringify({ document_id: documentId, content_hash: hash, normalized_text: text, http_status: response.status }),
          });
          await rest("research_findings", {
            method: "POST",
            body: JSON.stringify({
              research_job_id: job.id,
              snapshot_id: snapshots[0].id,
              finding_type: "changed",
              summary: `Content changed at ${source.base_url}; admin review required.`,
            }),
          });
          changed++;
        }
        await rest(`research_sources?id=eq.${source.id}`, {
          method: "PATCH",
          body: JSON.stringify({ last_attempt_at: new Date().toISOString(), last_success_at: new Date().toISOString() }),
        });
      } finally {
        clearTimeout(timer);
      }
    }
    await rest(`research_jobs?id=eq.${job.id}`, {
      method: "PATCH",
      body: JSON.stringify({ status: "succeeded", finished_at: new Date().toISOString() }),
    });
    return Response.json({ processed: 1, changed });
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : "research_sync_failed" }, { status: 500 });
  }
});
