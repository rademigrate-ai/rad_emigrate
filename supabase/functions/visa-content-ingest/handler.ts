import { bodyJson, contractValid } from "../_shared/rad_contract.ts";
import { purposeAuthorized, type WorkerDb } from "../_shared/purpose_worker.ts";

export function createVisaIngestHandler(
  options: { enabled: boolean; token: string; database: WorkerDb },
) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return Response.json({ error: "method_not_allowed" }, { status: 405 });
    }
    if (!options.enabled) {
      return Response.json({ error: "content_ingest_disabled" }, {
        status: 503,
      });
    }
    if (
      !await purposeAuthorized(
        options.token,
        request.headers.get("x-rad-content-token"),
      )
    ) return Response.json({ error: "forbidden" }, { status: 403 });
    let body;
    try {
      body = await bodyJson(request, 32000);
    } catch {
      return Response.json({ error: "invalid_request" }, { status: 422 });
    }
    if (!contractValid("visa_content_ingest_request", body)) {
      return Response.json({ error: "invalid_request" }, { status: 422 });
    }
    try {
      const result = await options.database("rpc/ingest_visa_snapshots", {
        method: "POST",
        body: JSON.stringify({ p_request: body }),
      });
      return Response.json(result);
    } catch (error) {
      const status = (error as { status?: number }).status;
      return Response.json({
        error: status === 409 ? "revision_conflict" : "ingest_unavailable",
      }, { status: status === 409 ? 409 : 503 });
    }
  };
}
