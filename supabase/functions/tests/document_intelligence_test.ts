Deno.env.set("SUPABASE_URL", "https://db.example.com");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-only-service-canary");

const { handler, isSafePublicHttpsUrl } = await import(
  "../document-intelligence/index.ts"
);

function assert(
  value: unknown,
  message = "document intelligence assertion failed",
) {
  if (!value) throw new Error(message);
}

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

type Scenario = {
  document?: Record<string, unknown>;
  endpoint?: string;
};

async function exercise(scenario: Scenario) {
  const original = globalThis.fetch;
  let providerCalls = 0;
  const writes: Array<{ path: string; body: Record<string, unknown> | null }> =
    [];
  globalThis.fetch = async (input, init) => {
    await Promise.resolve();
    const url = String(input);
    const path = url.split("/rest/v1/")[1] ?? url;
    const body = init?.body ? JSON.parse(String(init.body)) : null;
    if (url.includes("/auth/v1/user")) return json({ id: "user-a" });
    if (path.startsWith("documents?")) {
      return json(scenario.document ? [scenario.document] : []);
    }
    if (path === "document_processing_jobs?select=id") {
      writes.push({ path, body });
      return json([{ id: "job-one" }]);
    }
    if (path === "rpc/get_document_processor_runtime") {
      return json([{
        provider_slug: "fixture",
        endpoint_url: scenario.endpoint ?? "https://ocr.example.com/process",
        api_key: "test-only-provider-key",
        max_file_bytes: 10_000_000,
        timeout_ms: 1000,
      }]);
    }
    if (path.startsWith("document_processing_jobs?id=")) {
      writes.push({ path, body });
      return json(null);
    }
    if (url.includes("/storage/v1/object/documents/")) {
      return new Response(new Uint8Array([1, 2, 3]), {
        headers: { "Content-Type": "application/pdf" },
      });
    }
    if (url.startsWith("https://ocr.example.com")) {
      providerCalls++;
      return json({ text: "fixture" });
    }
    throw new Error(`Unexpected request: ${url}`);
  };
  try {
    const response = await handler(
      new Request("https://edge.example.com", {
        method: "POST",
        headers: {
          authorization: "Bearer user-token",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ document_id: "document-one" }),
      }),
    );
    return {
      status: response.status,
      body: await response.json(),
      providerCalls,
      writes,
    };
  } finally {
    globalThis.fetch = original;
  }
}

Deno.test("OCR lookup binds document id to the authenticated owner", async () => {
  const result = await exercise({});
  assert(result.status === 404);
  assert(result.providerCalls === 0);
  assert(result.writes.length === 0);
});

Deno.test("OCR rejects a database path outside the authenticated namespace", async () => {
  const result = await exercise({
    document: {
      id: "document-one",
      user_id: "user-a",
      file_path: "user-b/document-one/passport.pdf",
      name: "passport.pdf",
    },
  });
  assert(result.status === 403);
  assert(result.providerCalls === 0);
  assert(result.writes.length === 0);
});

Deno.test("OCR rejects private provider endpoints before network access", async () => {
  const result = await exercise({
    document: {
      id: "document-one",
      user_id: "user-a",
      file_path: "user-a/document-one/passport.pdf",
      name: "passport.pdf",
    },
    endpoint: "https://169.254.169.254/latest/meta-data",
  });
  assert(result.status === 422);
  assert(result.body.code === "unsafe_provider_url");
  assert(result.providerCalls === 0);
});

Deno.test("public URL validation rejects loopback, private, and metadata hosts", () => {
  for (
    const url of [
      "http://ocr.example.com",
      "https://127.0.0.1",
      "https://10.0.0.1",
      "https://169.254.169.254",
      "https://metadata.google.internal",
      "https://service.internal",
      "https://[::1]",
    ]
  ) assert(!isSafePublicHttpsUrl(url), url);
  assert(isSafePublicHttpsUrl("https://ocr.example.com/v1"));
});
