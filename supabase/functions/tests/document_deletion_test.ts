import { createDocumentDeletionHandler } from "../document-deletion/handler.ts";

const requestId = "40000000-0000-4000-8000-000000000001";
const leaseToken = "50000000-0000-4000-8000-000000000002";
const serviceKey = "test-service-key";
const url = "https://stack.invalid";

const json = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), { status });

function equal(actual: unknown, expected: unknown, label = "") {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `${label} expected ${JSON.stringify(expected)}, got ${
        JSON.stringify(actual)
      }`,
    );
  }
}

type Options = {
  claim?: unknown;
  deleteStatus?: number;
  deleteThrows?: boolean;
  stillReadable?: boolean;
  probeStatus?: number;
  probeBody?: unknown;
  finalizeFails?: boolean;
};

async function exercise(options: Options = {}, authorized = true) {
  const calls: Array<{ path: string; method: string; body?: unknown }> = [];
  const stub: typeof fetch = (input, init) => {
    const href = typeof input === "string" ? input : (input as Request).url;
    const path = href.replace(url, "");
    const method = init?.method ?? "GET";
    let body: unknown;
    if (typeof init?.body === "string") {
      try {
        body = JSON.parse(init.body);
      } catch {
        body = init.body;
      }
    }
    calls.push({ path, method, body });

    if (path === "/rest/v1/rpc/claim_document_deletion") {
      const claim = "claim" in options ? options.claim : {
        request_id: requestId,
        lease_token: leaseToken,
        bucket_id: "documents",
        object_path: "user-1/file.pdf",
        attempts: 1,
      };
      return Promise.resolve(json(claim));
    }
    if (path === "/rest/v1/rpc/fail_document_deletion") {
      return Promise.resolve(json({ state: "pending_storage" }));
    }
    if (path === "/rest/v1/rpc/finalize_document_deletion") {
      return options.finalizeFails
        ? Promise.resolve(json({ error: "boom" }, 500))
        : Promise.resolve(json({ state: "finalized" }));
    }
    if (path.startsWith("/storage/v1/object/")) {
      if (method === "DELETE") {
        if (options.deleteThrows) {
          return Promise.reject(new Error("network down"));
        }
        return Promise.resolve(
          new Response(null, { status: options.deleteStatus ?? 200 }),
        );
      }
      // Verification probe. Real self-hosted Storage reports a missing
      // private object as HTTP 400 / statusCode=404 / code=NoSuchKey.
      const status = options.stillReadable ? 200 : options.probeStatus ?? 404;
      if (status === 200) {
        return Promise.resolve(new Response("bytes", { status }));
      }
      if (status === 400) {
        return Promise.resolve(
          json(
            options.probeBody ?? {
              statusCode: "404",
              error: "not_found",
              code: "NoSuchKey",
            },
            400,
          ),
        );
      }
      return Promise.resolve(new Response(null, { status }));
    }
    return Promise.resolve(json({ error: "unexpected" }, 500));
  };

  const handler = createDocumentDeletionHandler({
    url,
    serviceKey,
    fetch: stub,
  });
  const response = await handler(
    new Request(`${url}/document-deletion`, {
      method: "POST",
      headers: authorized ? { authorization: `Bearer ${serviceKey}` } : {},
    }),
  );
  return { response, body: await response.json(), calls };
}

Deno.test("successful deletion verifies the object is gone then finalizes", async () => {
  const { response, body, calls } = await exercise();
  equal(response.status, 200, "status");
  equal(body.state, "finalized", "state");
  const paths = calls.map((c) => `${c.method} ${c.path}`);
  if (!paths.includes("DELETE /storage/v1/object/documents/user-1/file.pdf")) {
    throw new Error(`storage delete not issued: ${JSON.stringify(paths)}`);
  }
  if (!paths.includes("GET /storage/v1/object/documents/user-1/file.pdf")) {
    throw new Error("deletion was not verified by a read-back probe");
  }
  if (!paths.some((p) => p.endsWith("finalize_document_deletion"))) {
    throw new Error("finalize was not called");
  }
});

Deno.test("a non-service caller cannot drive the worker", async () => {
  const { response, body, calls } = await exercise({}, false);
  equal(response.status, 401, "status");
  equal(body.error, "authentication_required", "error");
  equal(calls.length, 0, "no work claimed");
});

Deno.test("storage failure is never reported as success and stays retryable", async () => {
  const { response, body, calls } = await exercise({ deleteStatus: 500 });
  equal(response.status, 502, "status");
  equal(body.error, "storage_delete_failed", "error");
  if (calls.some((c) => c.path.endsWith("finalize_document_deletion"))) {
    throw new Error("finalize must not run after a failed storage delete");
  }
  const failure = calls.find((c) => c.path.endsWith("fail_document_deletion"));
  if (!failure) throw new Error("failure was not recorded");
});

Deno.test("a network error records a safe error code", async () => {
  const { response, calls } = await exercise({ deleteThrows: true });
  equal(response.status, 502, "status");
  const failure = calls.find((c) => c.path.endsWith("fail_document_deletion"));
  if (!failure) throw new Error("failure was not recorded");
  const code = (failure.body as Record<string, string>).p_error_code;
  if (!/^[a-z0-9_]{1,64}$/.test(code)) {
    throw new Error(
      `error code must be safe for the RPC contract, got ${code}`,
    );
  }
});

Deno.test("an object still readable after delete is treated as a failure", async () => {
  const { response, body, calls } = await exercise({ stillReadable: true });
  equal(response.status, 502, "status");
  equal(body.code, "storage_object_still_readable", "code");
  if (calls.some((c) => c.path.endsWith("finalize_document_deletion"))) {
    throw new Error("finalize must not run while the object is still readable");
  }
});

Deno.test("a 404 from storage is an idempotent success", async () => {
  const { response, body } = await exercise({ deleteStatus: 404 });
  equal(response.status, 200, "status");
  equal(body.state, "finalized", "state");
});

Deno.test("an empty queue is a no-op, not an error", async () => {
  const { response, body } = await exercise({ claim: null });
  equal(response.status, 200, "status");
  equal(body.processed, 0, "processed");
  equal(body.reason, "queue_empty", "reason");
});

Deno.test("an unsafe storage reference is refused without deleting anything", async () => {
  const { response, body, calls } = await exercise({
    claim: {
      request_id: requestId,
      lease_token: leaseToken,
      bucket_id: "documents",
      object_path: "../../etc/passwd",
      attempts: 1,
    },
  });
  equal(response.status, 422, "status");
  equal(body.error, "unsafe_storage_reference", "error");
  if (calls.some((c) => c.path.startsWith("/storage/v1/object/"))) {
    throw new Error("no storage call may be made for an unsafe reference");
  }
});

Deno.test("a finalize failure reports failure even though storage is gone", async () => {
  const { response, body } = await exercise({ finalizeFails: true });
  equal(response.status, 500, "status");
  equal(body.error, "finalize_failed", "error");
  equal(body.storage_deleted, true, "storage_deleted");
});

Deno.test("real self-hosted NoSuchKey probe confirms absence", async () => {
  const { response, body, calls } = await exercise({ probeStatus: 400 });
  equal(response.status, 200);
  equal(body.state, "finalized");
  if (!calls.some((call) => call.path.endsWith("finalize_document_deletion"))) {
    throw new Error("real Storage NoSuchKey must allow finalization");
  }
});

Deno.test("403 and 500 probes cannot certify object deletion", async () => {
  for (const probeStatus of [401, 403, 500]) {
    const { response, body, calls } = await exercise({ probeStatus });
    equal(response.status, 502);
    equal(body.code, "storage_absence_not_confirmed");
    if (
      calls.some((call) => call.path.endsWith("finalize_document_deletion"))
    ) {
      throw new Error("unauthorized or failed probe must not finalize a row");
    }
  }
});

Deno.test("unrecognized 400 response does not certify deletion", async () => {
  const { response, body, calls } = await exercise({
    probeStatus: 400,
    probeBody: { error: "permission_denied" },
  });
  equal(response.status, 502);
  equal(body.code, "storage_absence_not_confirmed");
  if (calls.some((call) => call.path.endsWith("finalize_document_deletion"))) {
    throw new Error("arbitrary Storage error must not finalize");
  }
});

Deno.test("object names are percent-encoded before Storage requests", async () => {
  const { response, calls } = await exercise({
    claim: {
      request_id: requestId,
      lease_token: leaseToken,
      bucket_id: "documents",
      object_path: "user/file?copy#1.pdf",
      attempts: 1,
    },
  });
  equal(response.status, 200);
  const path = "/storage/v1/object/documents/user/file%3Fcopy%231.pdf";
  if (!calls.some((call) => call.path === path && call.method === "DELETE")) {
    throw new Error("Storage DELETE must target exact percent-encoded object");
  }
});
