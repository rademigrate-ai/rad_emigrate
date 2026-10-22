export type Observation = {
  provider: "frankfurter" | "fawazahmed0";
  base: string;
  quote: string;
  rate: string;
  observation_date: string;
  source_url: string;
};

/** Preserve JSON numeric lexemes before parsing: FX never passes through binary floats. */
export function decimalJson(text: string): unknown {
  let output = "", quoted = false, escaped = false;
  for (let i = 0; i < text.length;) {
    const c = text[i];
    if (quoted) {
      output += c;
      if (escaped) escaped = false;
      else if (c === "\\") escaped = true;
      else if (c === '"') quoted = false;
      i++;
    } else if (c === '"') {
      quoted = true;
      output += c;
      i++;
    } else if (c === "-" || /[0-9]/.test(c)) {
      const value = text.slice(i).match(
        /^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?/,
      )?.[0];
      if (!value) throw new Error("invalid_provider_json");
      output += JSON.stringify(value);
      i += value.length;
    } else {
      output += c;
      i++;
    }
  }
  return JSON.parse(output);
}

export function decimal(value: unknown): string {
  if (
    typeof value !== "string" || value.length > 80 ||
    !/^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$/.test(value)
  ) {
    throw new Error("invalid_rate");
  }
  const [mantissa, exp = "0"] = value.toLowerCase().split("e");
  const exponent = Number(exp);
  if (!Number.isInteger(exponent) || Math.abs(exponent) > 38) {
    throw new Error("invalid_rate");
  }
  const [whole, fraction = ""] = mantissa.split(".");
  const digits = whole + fraction;
  const place = whole.length + exponent;
  const expanded = place <= 0
    ? `0.${"0".repeat(-place)}${digits}`
    : place >= digits.length
    ? digits + "0".repeat(place - digits.length)
    : `${digits.slice(0, place)}.${digits.slice(place)}`;
  const [a, b = ""] = expanded.split(".");
  const integral = a.replace(/^0+(?=\d)/, "");
  const fractional = b.replace(/0+$/, "");
  if (
    integral.length > 18 || fractional.length > 18 ||
    !/[1-9]/.test(integral + fractional)
  ) throw new Error("invalid_rate");
  return fractional ? `${integral}.${fractional}` : integral;
}

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_provider_schema");
  }
  return value as Record<string, unknown>;
}

function date(value: unknown, now: Date): string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error("invalid_observation_date");
  }
  const parsed = new Date(`${value}T00:00:00Z`);
  if (
    !Number.isFinite(parsed.getTime()) ||
    parsed.toISOString().slice(0, 10) !== value
  ) throw new Error("invalid_observation_date");
  const today = Date.parse(`${now.toISOString().slice(0, 10)}T00:00:00Z`);
  if (parsed.getTime() > today || today - parsed.getTime() > 7 * 86400000) {
    throw new Error("stale_provider_data");
  }
  return value;
}

async function bounded(fetcher: typeof fetch, url: string): Promise<unknown> {
  const response = await fetcher(url, {
    redirect: "error",
    signal: AbortSignal.timeout(8000),
    headers: { Accept: "application/json" },
  });
  if (!response.ok || !response.headers.get("content-type")?.includes("json")) {
    throw new Error("provider_unavailable");
  }
  const reader = response.body?.getReader();
  if (!reader) throw new Error("provider_unavailable");
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > 2 * 1024 * 1024) {
        throw new Error("provider_response_too_large");
      }
      chunks.push(value);
    }
  } catch (error) {
    await reader.cancel().catch(() => {});
    throw error;
  }
  const buffer = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    buffer.set(chunk, offset);
    offset += chunk.length;
  }
  return decimalJson(new TextDecoder("utf-8", { fatal: true }).decode(buffer));
}

export async function fetchObservation(
  base: string,
  quote: string,
  fetcher: typeof fetch = fetch,
  now = new Date(),
): Promise<Observation> {
  if (!/^[A-Z]{3}$/.test(base) || !/^[A-Z]{3}$/.test(quote) || base === quote) {
    throw new Error("invalid_currency_pair");
  }
  const primary =
    `https://api.frankfurter.dev/v2/rate/${base.toLowerCase()}/${quote.toLowerCase()}`;
  try {
    const row = record(await bounded(fetcher, primary));
    if (
      String(row.base).toUpperCase() !== base ||
      String(row.quote).toUpperCase() !== quote
    ) throw new Error("wrong_pair");
    return {
      provider: "frankfurter",
      base,
      quote,
      rate: decimal(row.rate),
      observation_date: date(row.date, now),
      source_url: primary,
    };
  } catch {
    /* A failed primary cannot relabel a fallback observation as Frankfurter. */
  }
  const b = base.toLowerCase(), q = quote.toLowerCase();
  const urls = [
    `https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${b}.min.json`,
    `https://latest.currency-api.pages.dev/v1/currencies/${b}.min.json`,
  ];
  for (const url of urls) {
    try {
      const row = record(await bounded(fetcher, url));
      return {
        provider: "fawazahmed0",
        base,
        quote,
        rate: decimal(record(row[b])[q]),
        observation_date: date(row.date, now),
        source_url: url,
      };
    } catch {
      /* Mirrors belong to one provider, not independent corroboration. */
    }
  }
  throw new Error("rate_unavailable");
}
