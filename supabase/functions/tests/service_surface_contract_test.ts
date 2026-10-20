/** Service surface regression: Edge modules and contracts required for Antigravity/Codex integration. */
import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";

const root = new URL("../", import.meta.url);

async function read(rel: string) {
  return await Deno.readTextFile(new URL(rel, root));
}

Deno.test("service inventory: core Edge functions exist", async () => {
  for (const path of [
    "ai-orchestrator/handler.ts",
    "ai-orchestrator/knowledge_grounding.ts",
    "currency-refresh/providers.ts",
    "research-sync/handler.ts",
    "notification-dispatch/handler.ts",
    "official-source-worker/handler.ts",
    "visa-content-ingest/handler.ts",
  ]) {
    const text = await read(path);
    assertEquals(text.length > 100, true, path);
  }
});

Deno.test("AI grounding uses verified-official RPC only", async () => {
  const g = await read("ai-orchestrator/knowledge_grounding.ts");
  assertStringIncludes(g, "retrieve_verified_official_claims");
  assertStringIncludes(g, 'verification_state !== "verified"');
  assertStringIncludes(g, "fresh <= Date.now()");
  assertEquals(g.includes("retrieve_knowledge"), false);
});

Deno.test("research-sync never writes feed_items and uses atomic ingest", async () => {
  const h = await read("research-sync/handler.ts");
  assertStringIncludes(h, "rpc/ingest_research_snapshot");
  assertStringIncludes(h, "create_research_review_candidate runs inside");
  assertEquals(/feed_items/.test(h), false);
  assertStringIncludes(h, 'redirect: "manual"');
  assertStringIncludes(h, "redirects <= 3");
});

Deno.test("currency providers: Frankfurter primary, Fawazahmed0 fallback, decimal-safe", async () => {
  const p = await read("currency-refresh/providers.ts");
  assertStringIncludes(p, "frankfurter");
  assertStringIncludes(p, "fawazahmed0");
  assertStringIncludes(p, "decimalJson");
  assertStringIncludes(p, "api.frankfurter.dev");
  assertEquals(p.includes("bonbast"), false);
});

Deno.test("User AI system prompt forbids invention and Feed publish", async () => {
  const h = await read("ai-orchestrator/handler.ts");
  assertStringIncludes(h, "never invent");
  assertStringIncludes(h, "Never publish Feed");
  assertStringIncludes(h, "UNTRUSTED_RETRIEVED_CONTENT");
  assertEquals(/microphone|camera|audio-process|image-process/i.test(h), false);
});
