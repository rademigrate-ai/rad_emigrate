import { createOfficialSourceHandler } from "../official-source-worker/handler.ts";
import { createBoundOfficialRefresh } from "../official-source-worker/refresh.ts";

const lease = {
  job_id: "82000000-0000-4000-8000-000000000001",
  lease_token: "82000000-0000-4000-8000-000000000002",
};
const target = {
  binding_id: "82000000-0000-4000-8000-000000000003",
  url: "https://official.example.org/info",
  expected_revision_id: "82000000-0000-4000-8000-000000000004",
  expected_snapshot_id: "82000000-0000-4000-8000-000000000005",
  verified_path_prefix: "/info",
};

Deno.test("bound refresh preserves complete raw bytes and sends only existing bound revision and snapshot", async () => {
  const raw =
    "<html><script>untrusted instructions</script><p>BEGIN_SOURCE متن اصلی END_SOURCE</p></html>";
  const calls: { path: string; body: Record<string, unknown> }[] = [];
  const refresh = createBoundOfficialRefresh((path, init) => {
    calls.push({ path, body: JSON.parse(String(init?.body)) });
    return Promise.resolve(
      path.includes("get_bound_official_refresh_targets")
        ? [target]
        : { changed: true, published: false },
    );
  }, (url, init) => {
    if (url !== target.url || init.redirect !== "manual" || !init.signal) {
      throw Error("unprotected request");
    }
    return Promise.resolve(
      new Response(raw, {
        headers: { "content-type": "text/html;charset=utf-8" },
      }),
    );
  });
  await refresh!(lease);
  const ingest = calls.find((call) =>
    call.path.includes("ingest_bound_official_refresh")
  )?.body;
  if (
    !ingest || ingest.p_expected_revision_id !== target.expected_revision_id ||
    ingest.p_expected_snapshot_id !== target.expected_snapshot_id ||
    ingest.p_binding_id !== target.binding_id
  ) throw Error("unbound proposal");
  if (
    new TextDecoder().decode(
      Uint8Array.from(
        atob(String(ingest.p_raw_base64)),
        (c) => c.charCodeAt(0),
      ),
    ) !== raw
  ) throw Error("raw evidence altered");
  if (
    String(ingest.p_normalized_text).includes("instructions") ||
    !String(ingest.p_normalized_text).includes("متن اصلی")
  ) throw Error("normalization or source language changed");
  if (calls.some((call) => /approve|publish|save_structured/.test(call.path))) {
    throw Error("worker crossed human review boundary");
  }
});

Deno.test("bound refresh fails closed for unsafe redirects, oversized text and missing bindings", async () => {
  for (const scenario of ["redirect", "large", "missing"] as const) {
    let ingests = 0, fetches = 0;
    const refresh = createBoundOfficialRefresh((path) => {
      if (path.includes("ingest_bound_official_refresh")) ingests++;
      return scenario === "missing"
        ? Promise.reject(Error("explicit_source_bindings_required"))
        : Promise.resolve([target]);
    }, () => {
      fetches++;
      return Promise.resolve(
        scenario === "redirect"
          ? new Response(null, {
            status: 302,
            headers: { location: "https://evil.example.org/private" },
          })
          : new Response("x".repeat(100001), {
            headers: { "content-type": "text/plain" },
          }),
      );
    });
    let rejected = false;
    try {
      await refresh!(lease);
    } catch {
      rejected = true;
    }
    if (!rejected || ingests || fetches !== (scenario === "missing" ? 0 : 1)) {
      throw Error("unsafe evidence was ingested");
    }
  }
  if (createBoundOfficialRefresh(() => Promise.resolve([]))) {
    throw Error("missing secure transport must remain unavailable");
  }
});
Deno.test("configured bound refresh executes the protected leased extension and closes the job", async () => {
  const token = "synthetic-refresh-token".repeat(3);
  let refreshed = false;
  let safeCode: unknown = "unset";
  const lease = {
    job_id: crypto.randomUUID(),
    lease_token: crypto.randomUUID(),
  };
  const options = {
    enabled: true,
    token,
    database: (path: string, init?: RequestInit) =>
      Promise.resolve(
        path.includes("get_official_research_job")
          ? {
            kind: "research_refresh",
            request: { authority_ids: [crypto.randomUUID()] },
          }
          : (safeCode = JSON.parse(String(init?.body)).p_safe_code, true),
      ),
    refresh: (job: { job_id: string; lease_token: string }) => {
      if (JSON.stringify(job) !== JSON.stringify(lease)) {
        throw Error(
          "wrong lease",
        );
      }
      refreshed = true;
      return Promise.resolve();
    },
  };
  const response = await createOfficialSourceHandler(options)(
    new Request("https://worker.example.invalid", {
      method: "POST",
      headers: { "x-rad-official-source-token": token },
      body: JSON.stringify(lease),
    }),
  );
  if (response.status !== 200 || !refreshed || safeCode !== null) {
    throw Error("configured refresh unavailable");
  }
});
