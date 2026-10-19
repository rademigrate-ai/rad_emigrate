import registry from "../../contracts/rad_v1.json" with { type: "json" };

type Schema = Record<string, unknown>;
const definitions = registry.$defs as Record<string, Schema>;
export function contractValid(name: string, value: unknown): boolean {
  const validate = (s: Schema | undefined, v: unknown, depth = 0): boolean => {
    if (!s || depth > 24) return false;
    if (s.$ref) {
      return validate(definitions[String(s.$ref).split("/")[2]], v, depth + 1);
    }
    if (s.anyOf) {
      return (s.anyOf as Schema[]).some((a) => validate(a, v, depth + 1));
    }
    if (s.oneOf) {
      return (s.oneOf as Schema[]).filter((a) => validate(a, v, depth + 1))
        .length === 1;
    }
    if ("const" in s && s.const !== v) return false;
    if (s.enum && !(s.enum as unknown[]).includes(v)) return false;
    const type = v === null ? "null" : Array.isArray(v) ? "array" : typeof v;
    if (
      s.type && s.type !== type &&
      !(s.type === "integer" && type === "number" && Number.isInteger(v))
    ) return false;
    if (type === "object") {
      const o = v as Record<string, unknown>,
        props = (s.properties ?? {}) as Record<string, Schema>;
      if ((s.required as string[] ?? []).some((k) => !(k in o))) return false;
      return Object.entries(o).every(([k, val]) =>
        props[k]
          ? validate(props[k], val, depth + 1)
          : s.additionalProperties !== false
      );
    }
    if (Array.isArray(v)) {
      return v.length >= Number(s.minItems ?? 0) &&
        v.length <= Number(s.maxItems ?? 10000) && (!s.items || v.every((a) =>
          validate(s.items as Schema, a, depth + 1)
        )) && (!s.uniqueItems || new Set(v.map((a) =>
              JSON.stringify(a)
            )).size === v.length);
    }
    if (typeof v === "string") {
      return [...v].length >= Number(s.minLength ?? 0) &&
        [...v].length <= Number(s.maxLength ?? 2000000) &&
        (!s.pattern || new RegExp(String(s.pattern), "u").test(v)) &&
        (!s.format || Number.isFinite(Date.parse(v)));
    }
    if (typeof v === "number") {
      return Number.isFinite(v) && v >= Number(s.minimum ?? -Infinity) &&
        v <= Number(s.maximum ?? Infinity);
    }
    return true;
  };
  return validate(definitions[name], value);
}

export const envelope = (data: unknown, locale: "fa" | "en" | null = null) => ({
  data,
  meta: {
    request_id: crypto.randomUUID(),
    contract_version: "1",
    server_time: new Date().toISOString(),
    requested_locale: locale,
    resolved_locale: locale,
    fallback_used: false,
  },
});
export async function bodyJson(
  request: Pick<Request, "body">,
  max = 2 * 1024 * 1024,
): Promise<unknown> {
  const reader = request.body?.getReader();
  if (!reader) throw new Error("invalid_json");
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > max) throw new Error("request_too_large");
      chunks.push(value);
    }
  } catch (error) {
    await reader.cancel().catch(() => {});
    throw error;
  }
  const bytes = new Uint8Array(size);
  let at = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, at);
    at += chunk.length;
  }
  return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
}
