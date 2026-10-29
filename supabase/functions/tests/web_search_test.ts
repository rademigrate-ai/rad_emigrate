import { assertEquals, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { shouldAutoSearch, formatSearchForPrompt } from "../ai-orchestrator/web_search.ts";
import { classifyQuestionIntent } from "../ai-orchestrator/question_intent.ts";

Deno.test("auto-search triggers on current/news queries", () => {
  assertEquals(shouldAutoSearch("What is the latest news about Canada immigration fees today?", "immigration_or_rad"), true);
  assertEquals(shouldAutoSearch("What is 2+2?", "general"), false);
});

Deno.test("immigration intent does not become general", () => {
  assertEquals(classifyQuestionIntent("UK student visa requirements 2026"), "immigration_or_rad");
  assertEquals(classifyQuestionIntent("Write a Python hello world"), "general");
});

Deno.test("formatSearchForPrompt does not invent sources on empty", () => {
  const text = formatSearchForPrompt({
    status: "empty",
    adapter: "duckduckgo_instant",
    query: "test",
    citations: [],
  });
  assert(text.includes("Do not invent"));
});
