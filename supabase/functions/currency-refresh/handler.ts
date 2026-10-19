import { fetchObservation } from "./providers.ts";

type Options = {
  enabled: boolean;
  token: string;
  database: (path: string, init?: RequestInit) => Promise<unknown>;
  fetcher?: typeof fetch;
};

export function createCurrencyHandler(options: Options) {
  return async (request: Request): Promise<Response> => {
    const json = (status: number, data: unknown) =>
      Response.json(data, { status });
    if (request.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }
    if (!options.enabled || options.token.length < 32) {
      return json(503, { error: "currency_refresh_disabled" });
    }
    const supplied = request.headers.get("x-rad-currency-token") ?? "";
    const hashes = await Promise.all(
      [options.token, supplied].map((s) =>
        crypto.subtle.digest("SHA-256", new TextEncoder().encode(s))
      ),
    );
    const [a, b] = hashes.map((s) => new Uint8Array(s));
    if (!supplied || supplied.length > 512 || a.some((s, i) => s !== b[i])) {
      return json(403, { error: "forbidden" });
    }
    let body: Record<string, unknown>;
    try {
      const raw = await request.text();
      if (raw.length > 8192) return json(413, { error: "request_too_large" });
      body = JSON.parse(raw);
      if (
        !body || typeof body !== "object" || Array.isArray(body) ||
        Object.keys(body).some((k) => k !== "pairs") ||
        !Array.isArray(body.pairs) || body.pairs.length < 1 ||
        body.pairs.length > 20
      ) throw new Error();
      for (const p of body.pairs) {
        if (
          !p || typeof p !== "object" ||
          Object.keys(p).sort().join(",") !== "base,quote" ||
          typeof p.base !== "string" || typeof p.quote !== "string" ||
          !/^[A-Z]{3}$/.test(p.base) || !/^[A-Z]{3}$/.test(p.quote) ||
          p.base === p.quote
        ) throw new Error();
      }
    } catch {
      return json(422, { error: "invalid_request" });
    }
    const results = [];
    for (const pair of body.pairs as { base: string; quote: string }[]) {
      try {
        const observation = await fetchObservation(
          pair.base,
          pair.quote,
          options.fetcher,
        );
        const id = await options.database("rpc/record_fx_observation", {
          method: "POST",
          body: JSON.stringify({ p_observation: observation }),
        });
        results.push({ ...pair, observation_id: id, status: "cached" });
      } catch {
        results.push({ ...pair, status: "unavailable" });
      }
    }
    return json(200, { results });
  };
}
