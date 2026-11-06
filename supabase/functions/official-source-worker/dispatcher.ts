import { purposeAuthorized, type WorkerDb } from "../_shared/purpose_worker.ts";

type Options = {
  enabled: boolean;
  token: string;
  database: WorkerDb;
  worker: (request: Request) => Promise<Response>;
};

/** Protected cron entry point for the existing leased official-research queue.
 * POST ?dispatch=1 claims one bounded chunk; it uses the same strict worker.
 * The database owns lease retries and terminal failure, never this dispatcher.
 */
export function createOfficialDispatcher(options: Options) {
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
    let claimed = 0, succeeded = 0, failed = 0, deferred = 0;
    try {
      for (let i = 0; i < 1; i++) {
        const job = await options.database("rpc/claim_official_research_job", {
          method: "POST",
          body: "{}",
        }) as { job_id: string; lease_token: string } | null;
        if (!job) break;
        if (
          typeof job.job_id !== "string" || typeof job.lease_token !== "string"
        ) throw new Error("invalid_lease");
        claimed++;
        const response = await options.worker(
          new Request(request.url.split("?")[0], {
            method: "POST",
            headers: {
              "x-rad-official-source-token": options.token,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              job_id: job.job_id,
              lease_token: job.lease_token,
            }),
          }),
        );
        const result = await response.json();
        if (response.status === 202 && result.status === "queued") deferred++;
        else if (response.ok && result.status === "succeeded") succeeded++;
        else failed++;
      }
      return Response.json({ claimed, succeeded, failed, deferred }, {
        status: failed ? 503 : deferred ? 202 : 200,
      });
    } catch {
      // An interrupted lease expires in the database; never invent completion.
      return Response.json({
        claimed,
        succeeded,
        failed,
        error: "official_dispatch_unavailable",
      }, { status: 503 });
    }
  };
}
