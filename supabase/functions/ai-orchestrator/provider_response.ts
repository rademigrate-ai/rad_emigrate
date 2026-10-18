export class ProviderError extends Error {
  constructor(readonly code: string, readonly status = 502) {
    super(code);
  }
}
type Row = Record<string, unknown>;
const row = (value: unknown): Row =>
  value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Row
    : {};
const list = (value: unknown): Row[] =>
  Array.isArray(value) ? value.map(row) : [];
const text = (value: unknown) => typeof value === "string" ? value : "";
const counter = (value: unknown): number | null =>
  typeof value === "number" && Number.isSafeInteger(value) && value >= 0 &&
    value <= 2147483647
    ? value
    : null;

export async function readProviderJson(
  response: Response,
  maximum = 1_000_000,
): Promise<unknown> {
  const reader = response.body?.getReader();
  if (!reader) throw new ProviderError("provider_malformed_response");
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    if (Number(response.headers.get("content-length")) > maximum) {
      await reader.cancel();
      throw new ProviderError("provider_response_too_large");
    }
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > maximum) {
        await reader.cancel();
        throw new ProviderError("provider_response_too_large");
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.length;
    }
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch (error) {
    if (error instanceof ProviderError) throw error;
    if (
      error instanceof DOMException &&
      ["TimeoutError", "AbortError"].includes(error.name)
    ) throw new ProviderError("provider_timeout", 504);
    throw new ProviderError("provider_malformed_response");
  } finally {
    reader.releaseLock();
  }
}

export function parseProviderResponse(
  adapter: string,
  value: unknown,
  secrets: readonly string[] = [],
) {
  const data = row(value);
  let reply = "";
  let refused = false;
  let truncated = false;
  let usage: Row = {};
  if (adapter === "openai_compatible") {
    const choice = list(data.choices)[0] ?? {};
    const message = row(choice.message);
    refused = !!text(message.refusal).trim() ||
      choice.finish_reason === "content_filter";
    reply = refused ? text(message.refusal) : text(message.content);
    truncated = choice.finish_reason === "length";
    usage = row(data.usage);
  } else if (adapter === "anthropic") {
    refused = data.stop_reason === "refusal";
    reply = list(data.content).filter((block) => block.type === "text").map(
      (block) => text(block.text),
    ).join("\n");
    truncated = ["max_tokens", "model_context_window_exceeded"].includes(
      String(data.stop_reason),
    );
    const source = row(data.usage);
    usage = {
      prompt_tokens: source.input_tokens,
      completion_tokens: source.output_tokens,
    };
  } else if (adapter === "gemini") {
    const candidate = list(data.candidates)[0] ?? {};
    const blockReason = row(data.promptFeedback).blockReason;
    refused = [
      "SAFETY",
      "RECITATION",
      "BLOCKLIST",
      "PROHIBITED_CONTENT",
      "SPII",
      "IMAGE_SAFETY",
      "ESCALATION",
      "PUP_LIMITED_DISABLED",
    ].includes(String(candidate.finishReason)) ||
      (typeof blockReason === "string" &&
        !["", "BLOCK_REASON_UNSPECIFIED"].includes(blockReason));
    reply = list(row(candidate.content).parts).filter((part) =>
      part.thought === undefined || part.thought === false
    ).map((part) => text(part.text)).join("\n");
    truncated = ["MAX_TOKENS", "CONTINUATION"].includes(
      String(candidate.finishReason),
    );
    const source = row(data.usageMetadata);
    usage = {
      prompt_tokens: source.promptTokenCount,
      completion_tokens: source.candidatesTokenCount,
    };
  } else throw new ProviderError("unsupported_adapter", 400);
  reply = reply.trim();
  const valid = reply.length > 0 && reply.length <= 50000 &&
    !/[\x00-\x08\x0b\x0c\x0e-\x1f]/.test(reply) &&
    !secrets.some((secret) => secret.length > 0 && reply.includes(secret));
  if (!valid && !refused) {
    throw new ProviderError("provider_malformed_response");
  }
  // A refused result is terminal even if its accompanying text is unusable.
  return {
    text: valid ? reply : "",
    refused,
    truncated,
    usage: {
      prompt_tokens: counter(usage.prompt_tokens),
      completion_tokens: counter(usage.completion_tokens),
    },
  };
}
