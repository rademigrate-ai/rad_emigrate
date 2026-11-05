import { corsHeaders } from "../_shared/cors.ts";

// Hard document deletion. SQL cannot remove a Storage object, so this function
// is the only place that does: claim a leased work item, delete the object via
// the authorized Storage API, verify it is gone, then finalize the row deletion
// and the immutable receipt. A failed Storage delete is never reported as
// success -- the item stays retryable and the document stays inaccessible.

type Row = Record<string, unknown>;
type Options = { url: string; serviceKey: string; fetch: typeof fetch };

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

// Reject anything that could escape the owning bucket/prefix before it reaches
// the Storage API. The path comes from the database, but defence in depth here
// is cheap and a traversal would delete an unrelated object.
function safeObjectPath(value: unknown): string | null {
  const path = text(value);
  if (!path || path.length > 1024) return null;
  if (path.startsWith("/") || path.includes("..") || path.includes("\\")) {
    return null;
  }
  // Reject control characters by code point rather than a control-char regex.
  for (const character of path) {
    const code = character.codePointAt(0) ?? 0;
    if (code < 0x20 || code === 0x7f) return null;
  }
  return path;
}

function safeBucket(value: unknown): string | null {
  const bucket = text(value);
  return /^[a-z0-9][a-z0-9_-]{0,62}$/.test(bucket) ? bucket : null;
}

export function createDocumentDeletionHandler(options: Options) {
  const serviceHeaders = {
    apikey: options.serviceKey,
    Authorization: `Bearer ${options.serviceKey}`,
    "Content-Type": "application/json",
  };

  const rpc = async (name: string, body: Row): Promise<unknown> => {
    const response = await options.fetch(`${options.url}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: serviceHeaders,
      body: JSON.stringify(body),
      redirect: "error",
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error(`rpc_failed_${name}`);
    }
    return await response.json();
  };

  return async function handler(req: Request): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (req.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }
    if (!options.url || !options.serviceKey) {
      return json(503, { error: "document_deletion_unavailable" });
    }
    // Worker entry point: service-role only. User-facing deletion requests go
    // through the request_document_deletion RPC, not this function.
    const authorization = req.headers.get("authorization") ?? "";
    if (authorization !== `Bearer ${options.serviceKey}`) {
      return json(401, { error: "authentication_required" });
    }

    let claimed: Row;
    try {
      const raw = await rpc("claim_document_deletion", {});
      if (raw === null) {
        return json(200, { processed: 0, reason: "queue_empty" });
      }
      claimed = object(raw);
    } catch {
      return json(503, { error: "claim_failed" });
    }

    const requestId = text(claimed.request_id);
    const leaseToken = text(claimed.lease_token);
    const bucket = safeBucket(claimed.bucket_id);
    const path = safeObjectPath(claimed.object_path);
    if (!requestId || !leaseToken) {
      return json(503, { error: "claim_malformed" });
    }
    if (!bucket || !path) {
      // Never guess at a malformed reference; record it and stop.
      await rpc("fail_document_deletion", {
        p_request_id: requestId,
        p_lease_token: leaseToken,
        p_error_code: "unsafe_storage_reference",
      }).catch(() => undefined);
      return json(422, { error: "unsafe_storage_reference" });
    }

    // Storage rejects a JSON content-type on a body-less request, so the
    // object calls deliberately omit it rather than reusing serviceHeaders.
    const storageHeaders = {
      apikey: options.serviceKey,
      Authorization: `Bearer ${options.serviceKey}`,
    };
    // Encode every path segment: an object name containing ? or # must not
    // accidentally address a different object or truncate the Storage URL.
    const encodedPath = path.split("/").map(encodeURIComponent).join("/");
    const target = `${options.url}/storage/v1/object/${bucket}/${encodedPath}`;
    try {
      const removed = await options.fetch(target, {
        method: "DELETE",
        headers: storageHeaders,
        redirect: "error",
        signal: AbortSignal.timeout(20000),
      });
      // 404 is success for an idempotent delete: a previous attempt already
      // removed it, or it never existed. Anything else is a real failure.
      if (!removed.ok && removed.status !== 404) {
        await removed.body?.cancel();
        throw new Error(`storage_status_${removed.status}`);
      }
      await removed.body?.cancel();

      // Verify rather than trust the delete response.
      const probe = await options.fetch(target, {
        method: "GET",
        headers: storageHeaders,
        redirect: "error",
        signal: AbortSignal.timeout(15000),
      });
      const stillPresent = probe.ok;
      let confirmedAbsent = probe.status === 404;
      if (probe.status === 400) {
        // Real self-hosted Storage returns HTTP 400 with NoSuchKey for an
        // absent private object. A generic 4xx/5xx (including auth failures)
        // must NEVER certify deletion.
        const error = object(await probe.json().catch(() => null));
        confirmedAbsent = text(error.statusCode) === "404" &&
          text(error.error) === "not_found" &&
          text(error.code) === "NoSuchKey";
      } else {
        await probe.body?.cancel();
      }
      if (stillPresent) throw new Error("storage_object_still_readable");
      if (!confirmedAbsent) throw new Error("storage_absence_not_confirmed");
    } catch (error) {
      const message = text((error as Error)?.message);
      // Fetch errors can contain object paths and URLs. Only our fixed
      // classifications may be persisted or returned to an operator.
      const code =
        /^(storage_status_[1-5][0-9]{2}|storage_object_still_readable|storage_absence_not_confirmed)$/
            .test(message)
          ? message
          : "storage_network_error";
      await rpc("fail_document_deletion", {
        p_request_id: requestId,
        p_lease_token: leaseToken,
        p_error_code: code,
      }).catch(() => undefined);
      // Explicitly not a success response.
      return json(502, { error: "storage_delete_failed", code });
    }

    try {
      const finalized = object(
        await rpc("finalize_document_deletion", {
          p_request_id: requestId,
          p_lease_token: leaseToken,
        }),
      );
      return json(200, {
        processed: 1,
        request_id: requestId,
        state: text(finalized.state) || "finalized",
      });
    } catch {
      // Storage is gone but the row is not. The item keeps its stored reference
      // so a later attempt can finalize; this is reported as a failure.
      return json(500, { error: "finalize_failed", storage_deleted: true });
    }
  };
}

export const handler = createDocumentDeletionHandler({
  url: Deno.env.get("SUPABASE_URL") ?? "",
  serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  fetch,
});
