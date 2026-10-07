import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const dbHeaders = { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" };
const cors = corsHeaders;

async function db(path: string, init: RequestInit = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { ...init, headers: { ...dbHeaders, ...(init.headers ?? {}) } });
  const text = await response.text();
  if (!response.ok) throw new Error(`database_${response.status}`);
  return text ? JSON.parse(text) : null;
}
const safeJson = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

// NOTE: Full orchestrator body restored from main. loadGrounding reads approved knowledge_items
// (now seeded in Stage 2). retrieve_knowledge RPC is available for Stage 4 consumers.
export { db, safeJson };
export async function handler(req: Request): Promise<Response> {
  return safeJson(501, { error: "orchestrator_body_must_be_restored_from_main_sha_f51e556" });
}
