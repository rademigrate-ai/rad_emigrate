// deno-lint-ignore-file require-await, no-explicit-any
import {
  parseProviderResponse,
  ProviderError,
  readProviderJson,
} from "../ai-orchestrator/provider_response.ts";
import { isSafePublicHttpsUrl } from "../_shared/public_url.ts";
Deno.env.set("SUPABASE_URL", "https://db.example.com");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-only-service-canary");
const { callProvider } = await import(
  "../ai-orchestrator/handler_providers.ts"
);
function equal(a: unknown, b: unknown) {
  if (JSON.stringify(a) !== JSON.stringify(b)) {
    throw new Error(`Expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
  }
}
function rejects(run: () => unknown) {
  let error: unknown;
  try {
    run();
  } catch (value) {
    error = value;
  }
  equal(error instanceof ProviderError, true);
}

Deno.test("provider schema: non-text, empty and missing replies cannot become successful answers", () => {
  for (const content of [null, undefined, "", {}, ["text"], 42]) {
    rejects(() =>
      parseProviderResponse("openai_compatible", {
        choices: [{ message: { content } }],
      })
    );
  }
  for (const body of [null, [], {}, { content: [] }, { candidates: [] }]) {
    rejects(() => parseProviderResponse("openai_compatible", body));
  }
});
Deno.test("provider schema: only typed Claude text blocks are returned", () => {
  const result = parseProviderResponse("anthropic", {
    content: [
      { type: "thinking", thinking: "private synthetic reasoning" },
      { type: "text", text: "متن اول" },
      { type: "tool_use", input: {} },
      { type: "text", text: "متن دوم" },
    ],
    usage: { input_tokens: 3, output_tokens: 4 },
  });
  equal(result.text, "متن اول\nمتن دوم");
  equal(result.usage, { prompt_tokens: 3, completion_tokens: 4 });
});
Deno.test("provider schema: Gemini thought parts and non-text media are excluded", () => {
  const result = parseProviderResponse("gemini", {
    candidates: [{
      content: {
        parts: [
          { thought: true, text: "private reasoning" },
          { thought: "true", text: "invalid reasoning flag" },
          { text: "Public text" },
          { inlineData: { data: "not text" } },
          { text: "More text" },
        ],
      },
    }],
    usageMetadata: { promptTokenCount: 5, candidatesTokenCount: 6 },
  });
  equal(result.text, "Public text\n\nMore text");
  equal(result.usage, { prompt_tokens: 5, completion_tokens: 6 });
});
Deno.test("provider schema: malformed counters remain unknown and never coerce strings", () => {
  for (
    const count of [-1, 1.5, NaN, Infinity, 2147483648, "42", true, {}, null]
  ) {
    const result = parseProviderResponse("openai_compatible", {
      choices: [{ message: { content: "Synthetic answer" } }],
      usage: { prompt_tokens: count, completion_tokens: count },
    });
    equal(result.usage, { prompt_tokens: null, completion_tokens: null });
  }
  equal(
    parseProviderResponse("openai_compatible", {
      choices: [{ message: { content: "Synthetic" } }],
      usage: { prompt_tokens: 0, completion_tokens: 1 },
    }).usage,
    { prompt_tokens: 0, completion_tokens: 1 },
  );
});
Deno.test("provider schema: explicit refusal or filtering is preserved across adapters", () => {
  for (
    const [adapter, value] of [
      ["openai_compatible", {
        choices: [{ message: { content: null, refusal: "Synthetic refusal" } }],
      }],
      ["openai_compatible", {
        choices: [{
          message: { content: null },
          finish_reason: "content_filter",
        }],
      }],
      ["anthropic", { content: [], stop_reason: "refusal" }],
      ["gemini", { candidates: [{ finishReason: "SAFETY" }] }],
      ["gemini", { promptFeedback: { blockReason: "PROHIBITED_CONTENT" } }],
    ] as const
  ) equal(parseProviderResponse(adapter, value).refused, true);
});
Deno.test("provider schema: partial outputs are marked across adapters", () => {
  for (
    const [adapter, value] of [
      ["openai_compatible", {
        choices: [{ message: { content: "Partial" }, finish_reason: "length" }],
      }],
      ["anthropic", {
        content: [{ type: "text", text: "Partial" }],
        stop_reason: "max_tokens",
      }],
      ["gemini", {
        candidates: [{
          content: { parts: [{ text: "Partial" }] },
          finishReason: "MAX_TOKENS",
        }],
      }],
    ] as const
  ) equal(parseProviderResponse(adapter, value).truncated, true);
});
Deno.test("provider schema: known credential echoes and excessive/control text are suppressed", () => {
  for (const content of ["secret-canary", "a".repeat(50001), "bad\u0000text"]) {
    rejects(() =>
      parseProviderResponse("openai_compatible", {
        choices: [{ message: { content } }],
      }, ["secret-canary"])
    );
  }
  const refusal = parseProviderResponse("openai_compatible", {
    choices: [{ message: { refusal: "secret-canary" } }],
  }, ["secret-canary"]);
  equal(refusal.text, "");
  equal(refusal.refused, true);
});
Deno.test("provider JSON: declared and streamed oversized bodies are bounded and cancelled", async () => {
  for (const declared of [true, false]) {
    let cancelled = false;
    const stream = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new Uint8Array(2048));
      },
      cancel() {
        cancelled = true;
      },
    });
    let code = "";
    try {
      await readProviderJson(
        new Response(stream, {
          headers: declared ? { "content-length": "2048" } : {},
        }),
        1024,
      );
    } catch (error) {
      code = (error as ProviderError).code;
    }
    equal(code, "provider_response_too_large");
    equal(cancelled, true);
  }
});
Deno.test("provider JSON: malformed UTF-8 and JSON expose only a fixed error", async () => {
  for (
    const body of [new Uint8Array([255]).buffer, "private malformed diagnostic"]
  ) {
    let message = "";
    try {
      await readProviderJson(new Response(body));
    } catch (error) {
      message = (error as Error).message;
    }
    equal(message, "provider_malformed_response");
  }
});
Deno.test("provider JSON: timeout remains distinct from malformed data", async () => {
  const stream = new ReadableStream({
    start(controller) {
      controller.error(
        new DOMException("private timeout diagnostic", "TimeoutError"),
      );
    },
  });
  let code = "";
  try {
    await readProviderJson(new Response(stream));
  } catch (error) {
    code = (error as ProviderError).code;
  }
  equal(code, "provider_timeout");
});
Deno.test("provider URL: mapped/compatible IPv6, local ranges and trailing-dot aliases are denied", () => {
  for (
    const url of [
      "https://[::ffff:127.0.0.1]",
      "https://[::ffff:7f00:1]",
      "https://[::7f00:1]",
      "https://[::1]",
      "https://[fea0::1]",
      "https://[fd00::1]",
      "https://[ff02::1]",
      "https://localhost.",
      "https://metadata.google.internal.",
      "https://device.home.arpa",
      "https://2130706433",
      "https://192.0.2.1",
      "https://198.18.1.1",
      "https://203.0.113.1",
      "https://name:secret@example.com",
      "http://example.com",
    ]
  ) equal(isSafePublicHttpsUrl(url), false);
});
Deno.test("provider URL: valid public DNS and global literal addresses remain compatible", () => {
  for (
    const url of [
      "https://api.example.com/v1",
      "https://8.8.8.8/v1",
      "https://[2606:4700:4700::1111]/v1",
    ]
  ) equal(isSafePublicHttpsUrl(url), true);
});
Deno.test("provider requests: trusted system instructions use each adapter's native field", async () => {
  const original = globalThis.fetch;
  try {
    for (const adapter of ["openai_compatible", "anthropic", "gemini"]) {
      let body: any;
      globalThis.fetch = async (_url, init) => {
        body = JSON.parse(String(init?.body));
        return Response.json(
          adapter === "openai_compatible"
            ? { choices: [{ message: { content: "Synthetic" } }] }
            : adapter === "anthropic"
            ? { content: [{ type: "text", text: "Synthetic" }] }
            : { candidates: [{ content: { parts: [{ text: "Synthetic" }] } }] },
        );
      };
      const result = await callProvider({
        provider_id: "synthetic",
        provider_slug: "synthetic",
        adapter,
        base_url: "https://provider.example.com",
        api_key: "test-only-provider-key",
        credential_version: 1,
        model_id: "model",
        model_slug: "model",
        max_output_tokens: 20,
        request_timeout_seconds: 5,
        max_retries: 0,
      }, [{ role: "system", content: "TRUSTED_INSTRUCTION" }, {
        role: "user",
        content: "UNTRUSTED_DATA",
      }]);
      equal(result.text, "Synthetic");
      if (adapter === "openai_compatible") {
        equal(body.messages[0], {
          role: "system",
          content: "TRUSTED_INSTRUCTION",
        });
      } else if (adapter === "anthropic") {
        equal(body.system, "TRUSTED_INSTRUCTION");
        equal(body.messages, [{ role: "user", content: "UNTRUSTED_DATA" }]);
      } else {
        equal(body.systemInstruction, {
          parts: [{ text: "TRUSTED_INSTRUCTION" }],
        });
        equal(body.contents, [{
          role: "user",
          parts: [{ text: "UNTRUSTED_DATA" }],
        }]);
      }
    }
  } finally {
    globalThis.fetch = original;
  }
});
