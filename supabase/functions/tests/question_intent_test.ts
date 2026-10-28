import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { classifyQuestionIntent } from "../ai-orchestrator/question_intent.ts";

Deno.test("general knowledge stays general", () => {
  assertEquals(classifyQuestionIntent("What is photosynthesis?"), "general");
  assertEquals(classifyQuestionIntent("چطور کیک شکلاتی بپزم؟"), "general");
  assertEquals(classifyQuestionIntent("Explain bubble sort in Python"), "general");
});

Deno.test("immigration questions are evidence-gated", () => {
  assertEquals(classifyQuestionIntent("How do I apply for a UK student visa?"), "immigration_or_rad");
  assertEquals(classifyQuestionIntent("شرایط ویزای کار کانادا چیست؟"), "immigration_or_rad");
  assertEquals(classifyQuestionIntent("Express Entry CRS score factors"), "immigration_or_rad");
});

Deno.test("app help intent", () => {
  assertEquals(classifyQuestionIntent("How do I open my profile settings?"), "app_help");
  assertEquals(classifyQuestionIntent("کجا صفحه پروفایل را باز کنم؟"), "app_help");
});
