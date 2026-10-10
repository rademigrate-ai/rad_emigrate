Deno.env.set("SUPABASE_URL", "https://db.example.com");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-only-service-canary");
const { handler } = await import("../research-sync/handler.ts");
const json = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), { status });
function assert(value: unknown) {
  if (!value) throw new Error("Research assertion failed");
}
async function run(
  role = "admin",
  sourceStatus = 200,
  changed: unknown = "finding-one",
) {
  const saved: Array<{
    path: string;
    body: Record<string, unknown> | null;
  }> = [];
  const original = globalThis.fetch;
  let sourceCalls = 0;
  globalThis.fetch = async (input, init) => {
    await Promise.resolve();
    const url = String(input);
    const path = url.split("/rest/v1/")[1] ?? url;
    const body = init?.body
      ? JSON.parse(String(init.body)) as Record<string, unknown>
      : null;
    saved.push({ path, body });
    if (url.includes("/auth/v1/user")) return json({ id: "user-one" });
    if (path.startsWith("profiles?")) return json([{ role }]);
    if (path.startsWith("research_worker_config?")) {
      return json([{
        invocation_token: "test-only-worker",
        max_sources_per_run: 5,
        request_timeout_ms: 1000,
      }]);
    }
    if (path.startsWith("research_jobs?")) {
      return json([{ id: "job-one", attempts: 0 }]);
    }
    if (path.startsWith("research_jobs?id=") && path.includes("select=id")) {
      return json([{ id: "job-one" }]);
    }
    if (path.startsWith("research_sources?")) {
      return json([{
        id: "source-one",
        base_url: "https://source.example.com/article",
        allowed_host: "source.example.com",
        authority: "external",
        trust_class: "external",
        source_type: "admin_defined",
      }]);
    }
    if (path.startsWith("source_documents?")) {
      return json([{ id: "document-one", language_code: "fa" }]);
    }
    if (path === "rpc/ingest_research_snapshot") return json(changed);
    if (url.startsWith("https://source.example.com")) {
      sourceCalls++;
      return new Response("متن منبع برای بررسی انسانی", {
        status: sourceStatus,
      });
    }
    return json(null);
  };
  try {
    const result = await handler(
      new Request("https://edge.example.com", {
        method: "POST",
        headers: { Authorization: "Bearer user-test-token" },
      }),
    );
    return {
      status: result.status,
      body: await result.json(),
      saved,
      sourceCalls,
    };
  } finally {
    globalThis.fetch = original;
  }
}
Deno.test("Research fetch invokes one atomic ingest with exact Unicode evidence and attribution", async () => {
  const x = await run();
  const write = x.saved.find((c) => c.path === "rpc/ingest_research_snapshot");
  assert(x.status === 200 && x.body.changed === 1);
  assert(write?.body?.p_normalized_text === "متن منبع برای بررسی انسانی");
  assert(String(write?.body?.p_content_hash).length === 64);
  const metadata = write?.body?.p_metadata as Record<string, unknown>;
  assert(metadata.trust_class === "external");
  assert(
    !x.saved.some((c) =>
      /feed_items|content_drafts|research_findings$|source_snapshots$/.test(
        c.path,
      )
    ),
  );
});
Deno.test("Unchanged evidence reports no new candidate", async () => {
  const x = await run("admin", 200, null);
  assert(x.body.changed === 0);
});
Deno.test("Source failure is visible and sanitized without a fake finding", async () => {
  const x = await run("admin", 503);
  assert(x.body.failed === 1 && x.body.changed === 0);
  assert(x.saved.some((c) => c.body?.last_error_code === "source_http_503"));
  assert(!x.saved.some((c) => c.path === "rpc/ingest_research_snapshot"));
});
Deno.test("Ordinary users cannot start Research or read worker credentials", async () => {
  const x = await run("user");
  assert(x.status === 403 && x.sourceCalls === 0);
  assert(!/test-only-service|test-only-worker/.test(JSON.stringify(x.body)));
});
