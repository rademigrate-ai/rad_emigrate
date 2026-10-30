import { createAuthorityDiscovery } from "../official-source-worker/discovery.ts";
import { createOfficialSourceHandler } from "../official-source-worker/handler.ts";
import type { WebSearchResult } from "../ai-orchestrator/web_search.ts";

const scope = { country_code: "CA", topic: "study", profession: null };
const result = (status: WebSearchResult["status"]): WebSearchResult => ({
  status,
  adapter: "synthetic",
  query: "fixture",
  citations: [],
});

Deno.test("authority discovery searches bounded scope and retains only safe unverified candidates", async () => {
  let query = "";
  const discover = createAuthorityDiscovery((value) => {
    query = value;
    return Promise.resolve({
      ...result("ok"),
      citations: [
        {
          title: "Official study page",
          url: "https://www.canada.ca/study",
          publisher: "Canada",
          excerpt: "Untrusted instructions must never execute",
          retrieved_at: "2026-10-29T00:00:00Z",
        },
        {
          title: "Private network",
          url: "https://127.0.0.1/private",
          publisher: "fake",
          excerpt: "",
          retrieved_at: "2026-10-29T00:00:00Z",
        },
      ],
    });
  });
  const candidates = await discover(scope);
  if (!query.includes("CA") || !query.includes("study") || query.length > 300) {
    throw new Error("scope not bounded");
  }
  if (
    candidates.length !== 1 ||
    candidates[0].url !== "https://www.canada.ca/study"
  ) throw new Error("unsafe search result");
  if (Object.keys(candidates[0]).sort().join() !== "name,url") {
    throw new Error("search invented authority proof");
  }
});

Deno.test("unavailable or failed search cannot become successful zero-candidate discovery", async () => {
  for (const status of ["unavailable", "error"] as const) {
    let rejected = false;
    try {
      await createAuthorityDiscovery(() => Promise.resolve(result(status)))(
        scope,
      );
    } catch {
      rejected = true;
    }
    if (!rejected) throw new Error("provider failure hidden");
  }
  const empty = await createAuthorityDiscovery(() =>
    Promise.resolve(result("empty"))
  )(scope);
  if (empty.length) throw new Error("empty search invented candidates");
});

Deno.test("failed discovery closes its lease with a safe terminal error", async () => {
  const calls: { path: string; body: Record<string, unknown> }[] = [];
  const token = "synthetic-official-token-".repeat(3);
  const handler = createOfficialSourceHandler({
    enabled: true,
    token,
    discover: () =>
      Promise.reject(new Error("secret provider response must not escape")),
    database: (path, init) => {
      calls.push({ path, body: JSON.parse(String(init?.body)) });
      return Promise.resolve(
        path.includes("get_official_research_job")
          ? { kind: "authority_discovery", request: scope }
          : true,
      );
    },
  });
  const response = await handler(
    new Request("https://worker.example.invalid", {
      method: "POST",
      headers: { "x-rad-official-source-token": token },
      body: JSON.stringify({
        job_id: crypto.randomUUID(),
        lease_token: crypto.randomUUID(),
      }),
    }),
  );
  const finish = calls.find((call) =>
    call.path.includes("finish_official_research_job")
  );
  if (
    response.status !== 503 ||
    finish?.body.p_safe_code !== "discovery_unavailable"
  ) throw new Error("failed discovery lease was not closed");
  const body = await response.text();
  if (body.includes("secret") || body.includes("provider response")) {
    throw new Error("unsafe error leaked");
  }
});
