import { bodyJson, contractValid } from "../_shared/rad_contract.ts";
import { purposeAuthorized, type WorkerDb } from "../_shared/purpose_worker.ts";
import { isSafePublicHttpsUrl } from "../_shared/public_url.ts";

type Candidate = { name: string; url: string };
type Options = {
  enabled: boolean;
  token: string;
  chunked?: boolean;
  database: WorkerDb;
  refresh?: (
    lease: { job_id: string; lease_token: string },
  ) => Promise<void | { complete: boolean; processed: number }>;
  discover?: (
    scope: { country_code: string; topic: string; profession: string | null },
  ) => Promise<Candidate[]>;
};

/** Discovery produces candidate identities only. It cannot create trust proofs,
 * factual verified states, approve content, or publish. Protected refresh stays
 * unavailable until an approved root policy and pinned egress runtime are wired.
 */
export function createOfficialSourceHandler(options: Options) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return Response.json({ error: "method_not_allowed" }, { status: 405 });
    }
    if (!options.enabled) {
      return Response.json({ error: "official_source_worker_disabled" }, {
        status: 503,
      });
    }
    if (
      !await purposeAuthorized(
        options.token,
        request.headers.get("x-rad-official-source-token"),
      )
    ) return Response.json({ error: "forbidden" }, { status: 403 });
    let body: { job_id: string; lease_token: string };
    try {
      body = await bodyJson(request, 4096) as typeof body;
    } catch {
      return Response.json({ error: "invalid_request" }, { status: 422 });
    }
    if (!contractValid("official_source_worker_request", body)) {
      return Response.json({ error: "invalid_request" }, { status: 422 });
    }
    try {
      const job = await options.database("rpc/get_official_research_job", {
        method: "POST",
        body: JSON.stringify({
          p_job_id: body.job_id,
          p_lease_token: body.lease_token,
        }),
      }) as {
        kind: string;
        request: {
          country_code: string;
          topic: string;
          profession: string | null;
        };
      };
      let code: string | null = null;
      const candidates: { name: string; host: string }[] = [];
      if (job.kind === "authority_discovery" && options.discover) {
        const seen = new Set<string>();
        let found: Candidate[] = [];
        try {
          found = await options.discover(job.request);
        } catch {
          // Close the claimed lease even when search is unavailable. Provider
          // response text must not enter the audit record or client response.
          code = "discovery_unavailable";
        }
        for (const item of found.slice(0, 20)) {
          if (
            !item.name.trim() || item.name.length > 300 ||
            !isSafePublicHttpsUrl(item.url)
          ) continue;
          const host = new URL(item.url).hostname;
          if (seen.has(host)) continue;
          seen.add(host);
          candidates.push({ name: item.name.trim(), host });
        }
      } else if (job.kind === "research_refresh" && options.refresh) {
        try {
          const progress = await options.refresh(body);
          if (progress && !progress.complete) {
            await options.database("rpc/yield_bound_official_refresh", {
              method: "POST",
              body: JSON.stringify({
                p_job_id: body.job_id,
                p_lease_token: body.lease_token,
              }),
            });
            if (!options.chunked) {
              return Response.json({ error: "refresh_continuation_required" }, {
                status: 503,
              });
            }
            return Response.json({
              job_id: body.job_id,
              status: "queued",
              candidates: 0,
              verified: 0,
              safe_error_code: null,
            }, { status: 202 });
          }
        } catch {
          code = "source_unavailable";
        }
      } else {code = job.kind === "authority_discovery"
          ? "discovery_unavailable"
          : "protected_egress_unavailable";}
      await options.database("rpc/finish_official_research_job", {
        method: "POST",
        body: JSON.stringify({
          p_job_id: body.job_id,
          p_lease_token: body.lease_token,
          p_candidates: candidates,
          p_safe_code: code,
        }),
      });
      return Response.json({
        job_id: body.job_id,
        status: code ? "failed" : "succeeded",
        candidates: candidates.length,
        verified: 0,
        safe_error_code: code,
      }, { status: code ? 503 : 200 });
    } catch {
      return Response.json({ error: "worker_unavailable" }, { status: 503 });
    }
  };
}
