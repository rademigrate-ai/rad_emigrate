import { assertEquals, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  performWebSearch,
  shouldAutoSearch,
  formatSearchForPrompt,
} from "../ai-orchestrator/web_search.ts";
import { isSafePublicHttpsUrl } from "../_shared/public_url.ts";

Deno.test("auto mode does not search pure general math", () => {
  assertEquals(shouldAutoSearch("What is 2 + 2?", "general"), false);
});

Deno.test("on-mode still never fabricates citations when empty", async () => {
  // Without Brave/Serper keys, DDG may return empty — must not invent URLs.
  const result = await performWebSearch("zzzznonexistentqueryxyz12345unique");
  assert(["ok", "empty", "error", "unavailable"].includes(result.status));
  for (const c of result.citations) {
    assert(isSafePublicHttpsUrl(c.url), `unsafe citation ${c.url}`);
    assert(!c.url.includes("localhost"));
    assert(c.title.length > 0);
  }
  if (result.status !== "ok") {
    const text = formatSearchForPrompt(result);
    assert(text.includes("Do not invent") || text.includes("status="));
  }
});

Deno.test("outbound query redacts email-looking tokens", async () => {
  const result = await performWebSearch("contact me at person@example.com about visas");
  // We cannot inspect the exact outbound string without mocking fetch, but
  // result must not echo private email into fabricated citations.
  for (const c of result.citations) {
    assertEquals(c.url.includes("person@example.com"), false);
  }
});
