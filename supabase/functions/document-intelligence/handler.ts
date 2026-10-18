import { corsHeaders } from "../_shared/cors.ts";

type Row = Record<string, unknown>;
type Options = { url: string; serviceKey: string; fetch: typeof fetch };
class ProcessingError extends Error {
  constructor(readonly code: string, readonly status = 422) {
    super(code);
  }
}
const object = (value: unknown): Row =>
  value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Row
    : {};
const text = (value: unknown) => typeof value === "string" ? value : "";
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

// Deliberately excludes IP literals and local-only hostnames. DNS/egress policy
// must separately prevent rebinding; this syntactic check is not an egress firewall.
function safeEndpoint(value: unknown): string | null {
  try {
    const url = new URL(text(value));
    const host = url.hostname.toLowerCase().replace(/\.$/, "");
    if (
      url.protocol !== "https:" || url.username || url.password || url.hash ||
      !host.includes(".") || /[:\[\]]/.test(host) || /^[\d.]+$/.test(host) ||
      /(?:^|\.)(localhost|local|internal|test|invalid)$/.test(host)
    ) return null;
    return url.href;
  } catch {
    return null;
  }
}

async function boundedBytes(
  response: Response,
  maximum: number,
  code: string,
): Promise<Uint8Array<ArrayBuffer>> {
  if (Number(response.headers.get("content-length")) > maximum) {
    await response.body?.cancel();
    throw new ProcessingError(code);
  }
  const reader = response.body?.getReader();
  if (!reader) return new Uint8Array();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > maximum) {
        await reader.cancel();
        throw new ProcessingError(code);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return bytes;
}

function validSignature(bytes: Uint8Array, mime: string): boolean {
  const signature = mime === "application/pdf"
    ? [37, 80, 68, 70, 45]
    : mime === "image/png"
    ? [137, 80, 78, 71, 13, 10, 26, 10]
    : mime === "image/jpeg"
    ? [255, 216, 255]
    : [];
  return signature.length > 0 &&
    signature.every((value, i) => bytes[i] === value);
}

export function createDocumentHandler(options: Options) {
  const serviceHeaders = {
    apikey: options.serviceKey,
    Authorization: `Bearer ${options.serviceKey}`,
    "Content-Type": "application/json",
  };
  async function db(path: string, init: RequestInit = {}): Promise<unknown> {
    let response: Response;
    try {
      response = await options.fetch(`${options.url}/rest/v1/${path}`, {
        ...init,
        headers: {
          ...serviceHeaders,
          ...Object.fromEntries(new Headers(init.headers)),
        },
        redirect: "error",
        signal: AbortSignal.timeout(15000),
      });
    } catch {
      throw new ProcessingError("database_unavailable", 503);
    }
    if (!response.ok) throw new ProcessingError("database_unavailable", 503);
    try {
      const data = new TextDecoder().decode(
        await boundedBytes(response, 2_000_000, "database_unavailable"),
      );
      return data ? JSON.parse(data) : null;
    } catch {
      throw new ProcessingError("database_unavailable", 503);
    }
  }
  const first = (data: unknown) => Array.isArray(data) ? object(data[0]) : {};

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (req.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }
    const authorization = req.headers.get("authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) {
      return json(401, { error: "authentication_required" });
    }
    if (!options.url || !options.serviceKey) {
      return json(503, { error: "document_intelligence_unavailable" });
    }
    let jobId: string | undefined;
    try {
      const auth = await options.fetch(`${options.url}/auth/v1/user`, {
        headers: { apikey: options.serviceKey, Authorization: authorization },
        redirect: "error",
        signal: AbortSignal.timeout(10000),
      });
      if (!auth.ok) return json(401, { error: "authentication_required" });
      const userId = text(object(await auth.json()).id);
      if (!userId) return json(401, { error: "authentication_required" });
      let body: Row;
      try {
        const raw = await boundedBytes(
          new Response(req.body),
          8192,
          "request_too_large",
        );
        body = object(JSON.parse(new TextDecoder().decode(raw)));
      } catch (error) {
        return json(error instanceof ProcessingError ? 413 : 400, {
          error: error instanceof ProcessingError ? error.code : "invalid_json",
        });
      }
      const documentId = text(body.document_id);
      if (
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          documentId,
        )
      ) {
        return json(400, { error: "document_id_required" });
      }
      const document = first(
        await db(
          `documents?select=id,user_id,file_path,name&id=eq.${
            encodeURIComponent(documentId)
          }&user_id=eq.${encodeURIComponent(userId)}&limit=1`,
        ),
      );
      if (!document.id) return json(404, { error: "document_not_found" });
      const path = text(document.file_path);
      const segments = path.split("/");
      if (
        document.user_id !== userId || !path.startsWith(`${userId}/`) ||
        /[\\%\x00-\x1f\x7f]/.test(path) || segments.some((s) =>
          !s || s === "." || s === ".."
        )
      ) {
        return json(403, { error: "document_path_forbidden" });
      }
      const job = first(
        await db("document_processing_jobs?select=id", {
          method: "POST",
          headers: { Prefer: "return=representation" },
          body: JSON.stringify({
            document_id: document.id,
            user_id: userId,
            status: "running",
            attempt_count: 1,
            started_at: new Date().toISOString(),
          }),
        }),
      );
      jobId = text(job.id);
      if (!jobId) throw new ProcessingError("database_unavailable", 503);
      const config = first(
        await db("rpc/get_document_processor_runtime", {
          method: "POST",
          body: "{}",
        }),
      );
      if (!Object.keys(config).length) {
        throw new ProcessingError("no_ocr_provider_configured", 503);
      }
      const endpoint = safeEndpoint(config.endpoint_url);
      const key = text(config.api_key);
      if (
        !endpoint || !key || !text(config.provider_slug) ||
        !Number.isInteger(config.max_file_bytes) ||
        Number(config.max_file_bytes) < 1024 ||
        !Number.isInteger(config.timeout_ms) ||
        Number(config.timeout_ms) < 1000 || Number(config.timeout_ms) > 60000
      ) {
        throw new ProcessingError("invalid_ocr_configuration", 503);
      }
      const file = await options.fetch(
        `${options.url}/storage/v1/object/documents/${
          segments.map(encodeURIComponent).join("/")
        }`,
        {
          headers: {
            apikey: options.serviceKey,
            Authorization: `Bearer ${options.serviceKey}`,
          },
          redirect: "manual",
          signal: AbortSignal.timeout(15000),
        },
      );
      if (file.status >= 300 && file.status < 400) {
        throw new ProcessingError("storage_redirect_forbidden");
      }
      if (!file.ok) {
        throw new ProcessingError("document_file_unavailable");
      }
      const mime = (file.headers.get("content-type") ?? "").split(";")[0].trim()
        .toLowerCase();
      if (!["application/pdf", "image/jpeg", "image/png"].includes(mime)) {
        await file.body?.cancel();
        throw new ProcessingError("unsupported_file_type");
      }
      const bytes = await boundedBytes(
        file,
        Math.min(Number(config.max_file_bytes), 10 * 1024 * 1024),
        "file_too_large",
      );
      if (!validSignature(bytes, mime)) {
        throw new ProcessingError("invalid_file_signature");
      }
      const result = await options.fetch(endpoint, {
        method: "POST",
        redirect: "manual",
        signal: AbortSignal.timeout(Number(config.timeout_ms)),
        headers: {
          Authorization: `Bearer ${key}`,
          "Content-Type": mime,
          "X-Document-Name": encodeURIComponent(
            text(document.name).slice(0, 200),
          ),
        },
        body: bytes,
      });
      if (
        result.status >= 300 && result.status < 400
      ) throw new ProcessingError("provider_redirect_forbidden");
      if (!result.ok) {
        throw new ProcessingError(
          result.status === 429
            ? "provider_rate_limited"
            : "provider_request_failed",
        );
      }
      let parsed: Row;
      try {
        parsed = object(
          JSON.parse(
            new TextDecoder().decode(
              await boundedBytes(
                result,
                1_000_000,
                "provider_response_too_large",
              ),
            ),
          ),
        );
      } catch (error) {
        if (error instanceof ProcessingError) throw error;
        throw new ProcessingError("provider_malformed_response");
      }
      if (
        typeof parsed.text !== "string" || !parsed.text.trim()
      ) throw new ProcessingError("provider_malformed_response");
      const extraction = first(
        await db("document_extractions?select=id", {
          method: "POST",
          headers: { Prefer: "return=representation" },
          body: JSON.stringify({
            job_id: jobId,
            document_id: document.id,
            user_id: userId,
            engine: text(config.provider_slug).slice(0, 100),
            engine_version: text(parsed.version).slice(0, 100) || "unknown",
            extracted_text: parsed.text.slice(0, 200000),
            language_code: text(parsed.language_code).slice(0, 10) || null,
            overall_confidence: typeof parsed.confidence === "number" &&
                Number.isFinite(parsed.confidence)
              ? Math.max(0, Math.min(1, parsed.confidence))
              : null,
            page_count: Number.isInteger(parsed.page_count) &&
                Number(parsed.page_count) > 0
              ? parsed.page_count
              : null,
          }),
        }),
      );
      const extractionId = text(extraction.id);
      if (!extractionId) throw new ProcessingError("database_unavailable", 503);
      const fields = (Array.isArray(parsed.fields) ? parsed.fields : []).slice(
        0,
        200,
      ).map((value) => {
        const field = object(value);
        return {
          extraction_id: extractionId,
          field_key: text(field.key).replace(/[^a-zA-Z0-9_.-]/g, "_").slice(
            0,
            100,
          ),
          field_value: text(field.value).slice(0, 4000),
          confidence: typeof field.confidence === "number" &&
              Number.isFinite(field.confidence)
            ? Math.max(0, Math.min(1, field.confidence))
            : null,
          page_number:
            Number.isInteger(field.page_number) && Number(field.page_number) > 0
              ? field.page_number
              : null,
          bounding_box: null,
          review_status: "unreviewed",
        };
      }).filter((field) => field.field_key);
      if (fields.length) {
        await db("document_fields", {
          method: "POST",
          headers: { Prefer: "return=minimal" },
          body: JSON.stringify(fields),
        });
      }
      await db(`document_processing_jobs?id=eq.${encodeURIComponent(jobId)}`, {
        method: "PATCH",
        body: JSON.stringify({
          status: "review_required",
          finished_at: new Date().toISOString(),
        }),
      });
      return json(200, {
        job_id: jobId,
        extraction_id: extractionId,
        status: "review_required",
        field_count: fields.length,
      });
    } catch (error) {
      const code = error instanceof ProcessingError
        ? error.code
        : error instanceof DOMException &&
            (error.name === "TimeoutError" || error.name === "AbortError")
        ? "provider_timeout"
        : "processing_unavailable";
      if (jobId) {
        await db(
          `document_processing_jobs?id=eq.${encodeURIComponent(jobId)}`,
          {
            method: "PATCH",
            body: JSON.stringify({
              status: "failed",
              safe_error_code: code,
              finished_at: new Date().toISOString(),
            }),
          },
        ).catch(() => undefined);
      }
      return json(error instanceof ProcessingError ? error.status : 503, {
        error: code === "no_ocr_provider_configured"
          ? "document_intelligence_unavailable"
          : "document_processing_failed",
        code,
        ...(jobId ? { job_id: jobId } : {}),
      });
    }
  };
}

export const handler = (req: Request) =>
  createDocumentHandler({
    url: Deno.env.get("SUPABASE_URL") ?? "",
    serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    fetch: globalThis.fetch,
  })(req);
