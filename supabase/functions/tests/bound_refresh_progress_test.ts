import { createBoundOfficialRefresh } from "../official-source-worker/refresh.ts";

const lease = { job_id: crypto.randomUUID(), lease_token: crypto.randomUUID() };
const target = (url = "https://bound.example.org/info/page") => ({
  binding_id: crypto.randomUUID(),
  url,
  verified_path_prefix: "/info",
  expected_revision_id: crypto.randomUUID(),
  expected_snapshot_id: crypto.randomUUID(),
});

Deno.test("bound refresh rejects raw and encoded traversal before any source fetch", async () => {
  for (
    const path of [
      "/info/../private",
      "/info/%2e%2e/private",
      "/info/%2E%2E%2fprivate",
      "/info/%252e%252e/private",
      "/info/%5cprivate",
    ]
  ) {
    let fetched = 0;
    const refresh = createBoundOfficialRefresh(
      () => Promise.resolve([target("https://bound.example.org" + path)]),
      () => {
        fetched++;
        return Promise.resolve(new Response("body"));
      },
    )!;
    let failed = false;
    try {
      await refresh(lease);
    } catch {
      failed = true;
    }
    if (!failed || fetched) {
      throw Error("unproved path reached source transport: " + path);
    }
  }
});

Deno.test("bound refresh rejects redirect outside verified path before following it", async () => {
  let calls = 0;
  const refresh = createBoundOfficialRefresh(
    () => Promise.resolve([target()]),
    () => {
      calls++;
      return Promise.resolve(
        new Response(null, { status: 302, headers: { location: "/private" } }),
      );
    },
  )!;
  let failed = false;
  try {
    await refresh(lease);
  } catch {
    failed = true;
  }
  if (!failed || calls !== 1) throw Error("redirect escaped verified prefix");
});

Deno.test("bound refresh renews its live lease and processes one bounded chunk", async () => {
  const targets = [target(), target()];
  let completed = 0, renewals = 0, fetched = 0;
  const refresh = createBoundOfficialRefresh((path) => {
    if (path.includes("get_bound_official_refresh_targets")) {
      return Promise.resolve(targets.slice(completed));
    }
    if (path.includes("renew_bound_official_refresh_lease")) {
      renewals++;
      return Promise.resolve(true);
    }
    if (path.includes("ingest_bound_official_refresh")) {
      completed++;
      return Promise.resolve({ changed: false });
    }
    throw Error("unexpected database call");
  }, () => {
    fetched++;
    return Promise.resolve(
      new Response("BEGIN unchanged END", {
        headers: { "content-type": "text/plain" },
      }),
    );
  })!;
  const result = await refresh(lease) as unknown as {
    complete: boolean;
    processed: number;
  };
  if (
    fetched !== 1 || completed !== 1 || renewals < 2 || result.complete ||
    result.processed !== 1
  ) throw Error("unbounded chunk or unrenewed lease");
});

Deno.test("an already completed frozen job can finish without fetching again", async () => {
  let fetched = 0;
  const refresh = createBoundOfficialRefresh(
    () => Promise.resolve([]),
    () => {
      fetched++;
      return Promise.resolve(new Response("unexpected"));
    },
  )!;
  const result = await refresh(lease) as unknown as {
    complete: boolean;
    processed: number;
  };
  if (!result.complete || result.processed !== 0 || fetched) {
    throw Error("completed manifest replay fetched again");
  }
});
