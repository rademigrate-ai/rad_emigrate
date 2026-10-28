/**
 * Two-field provider onboarding helpers: Base URL + API Key only.
 * Detect OpenAI-compatible, Anthropic, or Gemini endpoints without admin model ranking.
 */

import { isSafePublicHttpsUrl } from "../_shared/public_url.ts";

export type DetectedAdapter = "openai_compatible" | "anthropic" | "gemini";

export type ProtocolDetection = {
  ok: boolean;
  adapter?: DetectedAdapter;
  normalized_base_url?: string;
  error?: string;
};

export function normalizeAndValidateBaseUrl(raw: string): ProtocolDetection {
  const trimmed = (raw ?? "").trim().replace(/\/$/, "");
  if (!trimmed) return { ok: false, error: "base_url_required" };
  if (!isSafePublicHttpsUrl(trimmed) && !isSafePublicHttpsUrl(trimmed + "/")) {
    // isSafePublicHttpsUrl requires full URL; try as-is
    try {
      const u = new URL(trimmed);
      if (u.protocol !== "https:") return { ok: false, error: "https_required" };
      if (!isSafePublicHttpsUrl(u.origin + u.pathname.replace(/\/$/, "") || u.origin)) {
        return { ok: false, error: "unsafe_base_url" };
      }
    } catch {
      return { ok: false, error: "invalid_base_url" };
    }
  }
  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    return { ok: false, error: "invalid_base_url" };
  }
  if (url.protocol !== "https:") return { ok: false, error: "https_required" };
  if (url.username || url.password) return { ok: false, error: "credentials_in_url_forbidden" };
  // Restrict to default HTTPS port to reduce SSRF pivot surface.
  if (url.port && url.port !== "" && url.port !== "443") {
    return { ok: false, error: "unsafe_port" };
  }
  if (!isSafePublicHttpsUrl(url.href.replace(/\/$/, "")) && !isSafePublicHttpsUrl(url.origin)) {
    return { ok: false, error: "unsafe_base_url" };
  }
  const host = url.hostname.toLowerCase();
  let adapter: DetectedAdapter = "openai_compatible";
  if (host.includes("anthropic.com") || url.pathname.includes("/v1/messages")) {
    adapter = "anthropic";
  } else if (host.includes("googleapis.com") || host.includes("generativelanguage")) {
    adapter = "gemini";
  }
  // Strip trailing /v1 or /chat path fragments to a stable API root where possible
  let base = `${url.origin}${url.pathname}`.replace(/\/$/, "");
  base = base.replace(/\/chat\/completions$/i, "").replace(/\/v1\/messages$/i, "");
  return { ok: true, adapter, normalized_base_url: base };
}

/** Probe which protocol the endpoint speaks using the API key (read-only list calls). */
export async function detectProviderProtocol(
  baseUrl: string,
  apiKey: string,
  fetchImpl: typeof fetch = fetch,
): Promise<ProtocolDetection> {
  const validated = normalizeAndValidateBaseUrl(baseUrl);
  if (!validated.ok || !validated.normalized_base_url) return validated;
  const base = validated.normalized_base_url;
  const key = (apiKey ?? "").trim();
  if (!key || key.length < 8 || key.length > 4096) {
    return { ok: false, error: "api_key_invalid" };
  }

  const tryOpenAI = async () => {
    const res = await fetchImpl(`${base}/models`, {
      headers: { Authorization: `Bearer ${key}`, Accept: "application/json" },
      redirect: "error",
      signal: AbortSignal.timeout(10000),
    });
    return res.ok;
  };
  const tryAnthropic = async () => {
    const res = await fetchImpl(`${base}/v1/models`, {
      headers: { "x-api-key": key, "anthropic-version": "2023-06-01", Accept: "application/json" },
      redirect: "error",
      signal: AbortSignal.timeout(10000),
    });
    return res.ok;
  };
  const tryGemini = async () => {
    const res = await fetchImpl(`${base}/v1beta/models?key=${encodeURIComponent(key)}`, {
      headers: { Accept: "application/json" },
      redirect: "error",
      signal: AbortSignal.timeout(10000),
    });
    return res.ok;
  };

  // Prefer host-based guess first, then fall back
  const order: DetectedAdapter[] = validated.adapter
    ? [validated.adapter, "openai_compatible", "anthropic", "gemini"]
    : ["openai_compatible", "anthropic", "gemini"];
  const seen = new Set<string>();
  for (const adapter of order) {
    if (seen.has(adapter)) continue;
    seen.add(adapter);
    try {
      const ok = adapter === "openai_compatible"
        ? await tryOpenAI()
        : adapter === "anthropic"
        ? await tryAnthropic()
        : await tryGemini();
      if (ok) return { ok: true, adapter, normalized_base_url: base };
    } catch {
      /* try next */
    }
  }
  return { ok: false, error: "protocol_detection_failed" };
}
