import { createOfficialDispatcher } from "../official-source-worker/dispatcher.ts";
import { contractValid } from "../_shared/rad_contract.ts";
import { createOfficialSourceHandler } from "../official-source-worker/handler.ts";

Deno.test("partial refresh queues durable continuation and is never counted as job success", async () => {
  const token = "synthetic-token".repeat(4);
  const job = { job_id: crypto.randomUUID(), lease_token: crypto.randomUUID() };
  let yielded = 0, finished = 0;
  const worker = createOfficialSourceHandler({
    enabled: true,
    token,
    chunked: true,
    refresh: () => Promise.resolve({ complete: false, processed: 1 }),
    database: (path) => {
      if (path.includes("get_official_research_job")) {
        return Promise.resolve({
          kind: "research_refresh",
          request: { authority_ids: [crypto.randomUUID()] },
        });
      }
      if (path.includes("yield_bound_official_refresh")) yielded++;
      if (path.includes("finish_official_research_job")) finished++;
      return Promise.resolve(true);
    },
  });
  const request = () =>
    new Request("https://worker.example.invalid", {
      method: "POST",
      headers: { "x-rad-official-source-token": token },
      body: JSON.stringify(job),
    });
  const response = await worker(request());
  const chunkBody = await response.json();
  if (
    response.status !== 202 ||
    contractValid("official_source_worker_response", chunkBody) ||
    !contractValid(
      "official_source_worker_chunk_response",
      chunkBody,
    ) ||
    yielded !== 1 || finished
  ) throw Error("continuation broke wire or publication boundary");
  const dispatch = createOfficialDispatcher({
    enabled: true,
    token,
    worker,
    database: () => Promise.resolve(job),
  });
  const result = await dispatch(request());
  const body = await result.json();
  if (
    result.status !== 202 || body.deferred !== 1 || body.succeeded ||
    body.failed || finished
  ) throw Error("partial work falsely reported complete");
});

Deno.test("official dispatcher purpose authorization precedes any queue access", async () => {
  let calls = 0;
  const handler = createOfficialDispatcher({
    enabled: true,
    token: "synthetic-token".repeat(4),
    database: () => {
      calls++;
      return Promise.resolve(null);
    },
    worker: () => Promise.resolve(Response.json({})),
  });
  const response = await handler(
    new Request("https://worker.example.invalid?dispatch=1", {
      method: "POST",
    }),
  );
  if (response.status !== 403 || calls) {
    throw new Error("unauthorized queue access");
  }
});

Deno.test("official dispatcher claims a lease and reports actual worker failure", async () => {
  const token = "synthetic-token".repeat(4);
  const job = { job_id: crypto.randomUUID(), lease_token: crypto.randomUUID() };
  let claims = 0, runs = 0;
  const handler = createOfficialDispatcher({
    enabled: true,
    token,
    database: (path) => {
      if (path !== "rpc/claim_official_research_job") {
        throw new Error("unexpected mutation");
      }
      return Promise.resolve(claims++ === 0 ? job : null);
    },
    worker: async (request) => {
      runs++;
      if (
        request.headers.get("x-rad-official-source-token") !== token ||
        JSON.stringify(await request.json()) !== JSON.stringify(job)
      ) throw new Error("lease binding");
      return Response.json({
        status: "failed",
        safe_error_code: "discovery_unavailable",
      }, { status: 503 });
    },
  });
  const response = await handler(
    new Request("https://worker.example.invalid?dispatch=1", {
      method: "POST",
      headers: { "x-rad-official-source-token": token },
    }),
  );
  const body = await response.json();
  if (
    runs !== 1 || body.claimed !== 1 || body.failed !== 1 ||
    body.succeeded !== 0 || response.status !== 503
  ) throw new Error("dispatch failure falsely succeeded");
});

Deno.test("official dispatcher bounds work per invocation and no-ops on an empty queue", async () => {
  const token = "synthetic-token".repeat(4);
  for (const empty of [true, false]) {
    let claims = 0;
    const handler = createOfficialDispatcher({
      enabled: true,
      token,
      database: () => {
        claims++;
        return Promise.resolve(
          empty
            ? null
            : { job_id: crypto.randomUUID(), lease_token: crypto.randomUUID() },
        );
      },
      worker: () => Promise.resolve(Response.json({ status: "succeeded" })),
    });
    const response = await handler(
      new Request("https://worker.example.invalid?dispatch=1", {
        method: "POST",
        headers: { "x-rad-official-source-token": token },
      }),
    );
    const body = await response.json();
    if (
      response.status !== 200 || claims !== 1 ||
      body.claimed !== (empty ? 0 : 1)
    ) throw new Error("unbounded queue claim");
  }
});
