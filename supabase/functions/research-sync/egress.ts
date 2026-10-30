import { isSafePublicHttpsUrl } from "../_shared/public_url.ts";

type Options = { url: string; token: string; fetch?: typeof fetch };

/** Adapter for scripts/research_egress.py behind reviewed HTTPS ingress.
 * Its allowlist, DNS pinning and robots policy are enforced at the egress host.
 * Missing/unsafe configuration must never fall back to direct source fetch.
 */
export function createResearchEgressFetch(options: Options) {
  let gateway: URL;
  try {
    gateway = new URL(options.url);
  } catch {
    return undefined;
  }
  if (
    !isSafePublicHttpsUrl(options.url) || gateway.pathname !== "/fetch" ||
    gateway.search || gateway.hash || options.token.length < 32
  ) return undefined;
  const send = options.fetch ?? fetch;
  return async (url: string, init: RequestInit): Promise<Response> => {
    if (!isSafePublicHttpsUrl(url)) throw new Error("unsafe_source_url");
    const response = await send(gateway.href, {
      method: "POST",
      redirect: "error",
      signal: init.signal ?? AbortSignal.timeout(20000),
      headers: {
        Authorization: `Bearer ${options.token}`,
        "Content-Type": "application/json",
      },
      // Never serialize init: it may contain caller credentials or private data.
      body: JSON.stringify({ url }),
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error("protected_research_transport_failed");
    }
    const reader = response.body?.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    if (!reader) throw new Error("protected_research_transport_failed");
    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 1_400_000) throw new Error("source_too_large");
        chunks.push(value);
      }
    } finally {
      await reader.cancel().catch(() => undefined);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    const envelope = JSON.parse(new TextDecoder().decode(bytes));
    if (
      !Number.isInteger(envelope.status) || envelope.status < 200 ||
      envelope.status > 599 || typeof envelope.body_base64 !== "string" ||
      envelope.body_base64.length > 1_333_336 ||
      !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(
        envelope.body_base64,
      )
    ) throw new Error("protected_research_transport_failed");
    const decoded = Uint8Array.from(
      atob(envelope.body_base64),
      (char) => char.charCodeAt(0),
    );
    if (decoded.length > 1_000_000) throw new Error("source_too_large");
    const headers = new Headers();
    for (const key of ["content-type", "location"]) {
      const value = envelope.headers?.[key];
      if (typeof value === "string" && value.length <= 4096) {
        headers.set(key, value);
      }
    }
    return new Response(
      [204, 205, 304].includes(envelope.status) ? null : decoded,
      { status: envelope.status, headers },
    );
  };
}
