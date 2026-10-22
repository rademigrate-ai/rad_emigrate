import { createCopilotHandler } from "../ai-orchestrator/copilot.ts";
import { contractValid } from "../_shared/rad_contract.ts";
const id = "a2000000-0000-4000-8000-000000000002";
const other = "b2000000-0000-4000-8000-000000000002";
const equal = (actual: unknown, expected: unknown) => {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${JSON.stringify(actual)} != ${JSON.stringify(expected)}`);
  }
};
const body = () => ({
  action: "chat",
  request_key: id,
  scope: "user",
  session_id: null,
  guest_key: null,
  locale: "en",
  authorized_data_scopes: [],
  context: { article_id: null, section_id: null, case_id: null },
  messages: [{ role: "user", content: "Synthetic question" }],
});
const evidence = () => ({
  claim_id: id,
  snapshot_id: other,
  citation_id: id,
  claim_text: "Synthetic claim, not immigration advice",
  excerpt: "Synthetic evidence",
  locator: "paragraph:1",
  url: "https://example.gov/policy",
  authority: "Synthetic authority",
  verification_state: "verified",
  verified_at: new Date(Date.now() - 1000).toISOString(),
  fresh_until: new Date(Date.now() + 86400000).toISOString(),
});
async function run(
  patch: {
    reservation?: unknown;
    failure?: number;
    settle?: boolean;
    actor?: { id: string; role: string } | null;
    input?: Record<string, unknown>;
    generated?: { text: string; refused?: boolean; truncated?: boolean };
    evidence?: unknown;
  } = {},
) {
  const calls: { path: string; args: Record<string, unknown> }[] = [];
  const actorCalls: { jwt: string; path: string }[] = [];
  let providerCalls = 0;
  const handler = createCopilotHandler({
    authenticate: () =>
      Promise.resolve(
        patch.actor === undefined ? { id, role: "user" } : patch.actor,
      ),
    database: (path, init) => {
      calls.push({ path, args: JSON.parse(String(init?.body ?? "{}")) });
      if (path === "rpc/reserve_rad_ai_request") {
        if (patch.failure) throw { status: patch.failure };
        return Promise.resolve(
          patch.reservation === undefined
            ? { allowed: true, request_id: id, limit: 5, count: 1 }
            : patch.reservation,
        );
      }
      if (path === "rpc/settle_rad_ai_request") {
        return Promise.resolve(patch.settle ?? true);
      }
      if (path === "rpc/retrieve_verified_official_claims") {
        return Promise.resolve({
          results: patch.evidence === undefined ? [evidence()] : patch.evidence,
        });
      }
      if (path === "rpc/get_ai_runtime_chain_versioned") {
        return Promise.resolve([{ provider_id: id }]);
      }
      throw new Error("unexpected service operation: " + path);
    },
    actorDatabase: (jwt) => (path) => {
      actorCalls.push({ jwt, path });
      return Promise.resolve(
        path.startsWith("applications?") ? [] : { data: { items: [] } },
      );
    },
    generate: () => {
      providerCalls++;
      return Promise.resolve(
        patch.generated ?? { text: JSON.stringify({ claim_ids: [id] }) },
      );
    },
  });
  const response = await handler(
    new Request("https://example.invalid", {
      method: "POST",
      headers: {
        authorization: "Bearer synthetic-owner",
        "content-type": "application/json",
      },
      body: JSON.stringify(patch.input ?? body()),
    }),
  );
  return {
    status: response.status,
    data: await response.json(),
    calls,
    actorCalls,
    providerCalls,
  };
}
Deno.test("v1 reserves the authenticated owner before tools and settles a closed grounded response", async () => {
  const result = await run();
  equal(result.status, 200);
  equal(contractValid("ai_orchestrator_response", result.data), true);
  equal(result.calls[0].path, "rpc/reserve_rad_ai_request");
  equal(result.calls[0].args.p_user_id, id);
  equal(result.calls.at(-1)?.path, "rpc/settle_rad_ai_request");
  equal(result.providerCalls, 1);
  equal(result.data.data.reply, "Synthetic claim, not immigration advice [1]");
  equal(result.data.data.evidence_state, "sufficient");
});
Deno.test("v1 denies unknown fields, unauthenticated and forged admin requests before reservation", async () => {
  for (
    const patch of [{ input: { ...body(), user_id: other } }, { actor: null }, {
      input: { ...body(), scope: "admin" },
    }]
  ) {
    const result = await run(patch);
    equal(result.calls.length, 0);
    equal(result.providerCalls, 0);
    equal([401, 403, 422].includes(result.status), true);
  }
});
Deno.test("v1 reservation failures and running replays never execute tools or providers", async () => {
  for (
    const patch of [
      { failure: 409 },
      { failure: 403 },
      { failure: 500 },
      { reservation: null },
      { reservation: { allowed: true, request_id: "forged" } },
      { reservation: { allowed: false } },
      {
        reservation: {
          allowed: true,
          request_id: id,
          replayed: true,
          state: "running",
        },
      },
    ]
  ) {
    const result = await run(patch);
    equal([403, 409, 429, 503].includes(result.status), true);
    equal(result.calls.length, 1);
    equal(result.actorCalls.length, 0);
    equal(result.providerCalls, 0);
  }
});
Deno.test("v1 completed replay returns persisted result with no new provider or settlement", async () => {
  const first = await run();
  const result = await run({
    reservation: {
      allowed: true,
      request_id: id,
      replayed: true,
      state: "succeeded",
      http_status: 200,
      response: first.data,
    },
  });
  equal(result.status, 200);
  equal(result.data, first.data);
  equal(result.calls.length, 1);
  equal(result.providerCalls, 0);
});
Deno.test("v1 private case tools require consent and forward the actor JWT with ownership filter", async () => {
  const input = {
    ...body(),
    context: { article_id: null, section_id: null, case_id: other },
  };
  const denied = await run({ input });
  equal(
    denied.actorCalls.some((c) => c.path.startsWith("applications?")),
    false,
  );
  equal(
    denied.data.data.tool_outcomes.some((o: { safe_code: string }) =>
      o.safe_code === "consent_required"
    ),
    true,
  );
  const allowed = await run({
    input: { ...input, authorized_data_scopes: ["cases"] },
  });
  const call = allowed.actorCalls.find((c) =>
    c.path.startsWith("applications?")
  );
  equal(call?.jwt, "Bearer synthetic-owner");
  equal(call?.path.includes(`id=eq.${other}&user_id=eq.${id}`), true);
  equal(
    allowed.data.data.tool_outcomes.some((o: { safe_code: string }) =>
      o.safe_code === "not_found"
    ),
    true,
  );
});
Deno.test("v1 refusal, truncation, forged selections and absent evidence never yield certain prose", async () => {
  for (
    const patch of [
      { generated: { text: "UNTRUSTED prose", refused: true } },
      { generated: { text: "UNTRUSTED prose", truncated: true } },
      { generated: { text: JSON.stringify({ claim_ids: [other] }) } },
      { evidence: [] },
    ]
  ) {
    const result = await run(patch);
    equal(result.status, 200);
    equal(result.data.data.uncertain, true);
    equal(result.data.data.evidence_state, "insufficient");
    equal(result.data.data.reply.includes("UNTRUSTED"), false);
    equal(contractValid("ai_orchestrator_response", result.data), true);
  }
});
Deno.test("v1 failed settlement never reports a successful answer or private diagnostic", async () => {
  const result = await run({ settle: false });
  equal(result.status, 503);
  equal(result.data.code, "settlement_rejected");
  equal(result.data.data, undefined);
});
Deno.test("wire date formats reject impossible dates rather than JavaScript normalization", () => {
  for (
    const value of [
      "2026-02-30T00:00:00Z",
      "2026-13-01T00:00:00Z",
      "2026-02-01T24:00:00Z",
      "2026-02-01T00:00:00+00:00",
    ]
  ) equal(contractValid("Timestamp", value), false);
  for (const value of ["2026-02-30", "2026-04-31"]) {
    equal(contractValid("Date", value), false);
  }
  equal(contractValid("Timestamp", "2024-02-29T00:00:00.123456Z"), true);
  equal(contractValid("Date", "2024-02-29"), true);
});
