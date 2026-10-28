import { assertEquals, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  normalizeAndValidateBaseUrl,
} from "../ai-orchestrator/protocol_detect.ts";
import { isSafePublicHttpsUrl } from "../_shared/public_url.ts";
import { classifyQuestionIntent } from "../ai-orchestrator/question_intent.ts";

Deno.test("rejects non-https base URLs", () => {
  const r = normalizeAndValidateBaseUrl("http://api.openai.com/v1");
  assertEquals(r.ok, false);
});

Deno.test("rejects localhost and metadata hosts", () => {
  assertEquals(normalizeAndValidateBaseUrl("https://localhost/v1").ok, false);
  assertEquals(normalizeAndValidateBaseUrl("https://127.0.0.1/v1").ok, false);
  assertEquals(normalizeAndValidateBaseUrl("https://169.254.169.254/latest").ok, false);
  assertEquals(normalizeAndValidateBaseUrl("https://metadata.google.internal/").ok, false);
});

Deno.test("accepts public https OpenAI-compatible URL", () => {
  const r = normalizeAndValidateBaseUrl("https://openrouter.ai/api/v1");
  assertEquals(r.ok, true);
  assertEquals(r.adapter, "openai_compatible");
});

Deno.test("detects anthropic host", () => {
  const r = normalizeAndValidateBaseUrl("https://api.anthropic.com");
  assertEquals(r.ok, true);
  assertEquals(r.adapter, "anthropic");
});

Deno.test("isSafePublicHttpsUrl blocks private ranges", () => {
  assertEquals(isSafePublicHttpsUrl("https://10.0.0.1/x"), false);
  assertEquals(isSafePublicHttpsUrl("https://192.168.1.1/x"), false);
  assertEquals(isSafePublicHttpsUrl("https://example.com/path"), true);
});

Deno.test("immigration questions never classify as general", () => {
  const samples = [
    "Canada Express Entry CRS",
    "UK student visa documents",
    "شرایط ویزای کار آلمان",
    "Schengen tourist visa fees",
  ];
  for (const s of samples) {
    assertEquals(classifyQuestionIntent(s), "immigration_or_rad", s);
  }
});

Deno.test("ordinary questions stay general", () => {
  assertEquals(classifyQuestionIntent("Explain merge sort"), "general");
  assertEquals(classifyQuestionIntent("Recipe for lentil soup"), "general");
});
