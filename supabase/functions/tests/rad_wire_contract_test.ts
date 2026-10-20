import fixtures from "../../contracts/fixtures/rad_v1_synthetic.json" with {
  type: "json",
};
import registry from "../../contracts/rad_v1.json" with { type: "json" };
import { contractValid } from "../_shared/rad_contract.ts";
import { createNotificationDispatchHandler } from "../notification-dispatch/handler.ts";
import { createOfficialSourceHandler } from "../official-source-worker/handler.ts";

Deno.test("real rolled-back SQL fixtures satisfy independent request and response validation", () => {
  if (fixtures.length < 50) {
    throw new Error("incomplete SQL acceptance fixture set");
  }
  for (const fixture of fixtures) {
    if (!contractValid(fixture.name + "_request", fixture.request)) {
      throw new Error("request contract: " + fixture.name);
    }
    if (!contractValid(fixture.name + "_response", fixture.response)) {
      throw new Error("response contract: " + fixture.name);
    }
  }
});

Deno.test("wire registry has no dangling definitions or duplicate operation names", () => {
  const names = registry.endpoints.map((operation) => operation.name);
  if (new Set(names).size !== names.length) {
    throw new Error("duplicate operation");
  }
  const visit = (value: unknown): void => {
    if (!value || typeof value !== "object") return;
    if (Array.isArray(value)) return value.forEach(visit);
    const object = value as Record<string, unknown>;
    if (
      object.$ref && !(String(object.$ref).split("/").at(-1)! in registry.$defs)
    ) {
      throw new Error("dangling definition: " + object.$ref);
    }
    Object.values(object).forEach(visit);
  };
  visit(registry);
});

Deno.test("closed backend inputs reject authority forgery and cross-owner fields", () => {
  for (
    const operation of [
      "create_feed_comment",
      "save_visa_reading_state",
      "save_visa_search_alias",
    ]
  ) {
    const fixture = fixtures.find((entry) => entry.name === operation);
    if (!fixture) throw new Error("missing regression fixture: " + operation);
    for (
      const extra of [{ user_id: crypto.randomUUID() }, { verified: true }, {
        role: "super_admin",
      }]
    ) {
      if (
        contractValid(operation + "_request", { ...fixture.request, ...extra })
      ) {
        throw new Error(operation + " admitted privileged unknown fields");
      }
    }
  }
});

Deno.test("notification worker returns the documented synchronous sandbox counters", async () => {
  const token = "synthetic-purpose-".repeat(3);
  const handler = createNotificationDispatchHandler({
    enabled: true,
    invocationToken: token,
    supabaseUrl: "http://127.0.0.1:60321",
    database: () => Promise.resolve([]),
  });
  const response = await handler(
    new Request("https://worker.example.invalid", {
      method: "POST",
      headers: { "x-rad-notification-token": token },
      body: JSON.stringify({ limit: 1 }),
    }),
  );
  if (
    response.status !== 200 ||
    !contractValid("notification_dispatch_response", await response.json())
  ) {
    throw new Error("sandbox transport response contract");
  }
  if (
    contractValid("notification_dispatch_request", {
      limit: 1,
      request_key: crypto.randomUUID(),
    })
  ) {
    throw new Error("obsolete asynchronous worker request accepted");
  }
});

Deno.test("official discovery response is a bounded unverified candidate result", async () => {
  const token = "synthetic-purpose-".repeat(3);
  const handler = createOfficialSourceHandler({
    enabled: true,
    token,
    discover: () =>
      Promise.resolve([{
        name: "SYNTHETIC authority",
        url: "https://authority.example.invalid/synthetic",
      }]),
    database: (path) =>
      Promise.resolve(
        path.includes("get_official_research_job")
          ? {
            kind: "authority_discovery",
            request: {
              country_code: "ZZ",
              topic: "synthetic",
              profession: null,
            },
          }
          : true,
      ),
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
  const body = await response.json();
  if (
    response.status !== 200 || body.verified !== 0 ||
    !contractValid("official_source_worker_response", body)
  ) {
    throw new Error("candidate worker response contract");
  }
});
