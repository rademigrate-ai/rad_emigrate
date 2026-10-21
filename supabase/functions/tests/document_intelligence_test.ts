// deno-lint-ignore-file no-explicit-any, require-await
import { createDocumentHandler } from "../document-intelligence/handler.ts";

const user = "10000000-0000-4000-8000-000000000001";
const documentId = "20000000-0000-4000-8000-000000000001";
const json = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), { status });
function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
type Options = {
  auth?: boolean;
  document?: boolean;
  path?: string;
  owner?: string;
  configured?: boolean;
  endpoint?: string;
  mime?: string;
  file?: Uint8Array;
  fileLength?: number;
  fileRedirect?: boolean;
  providerStatus?: number;
  providerBody?: unknown;
  providerError?: Error;
  databaseFailure?: string;
  runtimeFailure?: boolean;
  claim?: unknown;
};

async function exercise(
  options: Options = {},
  requestBody: unknown = { document_id: documentId },
  method = "POST",
  authenticated = true,
) {
  const calls: Array<{ path: string; init?: RequestInit; body?: any }> = [];
  // deno-lint-ignore require-await
  const fetcher: typeof fetch = async (input, init) => {
    const path = String(input);
    const body = typeof init?.body === "string" && path.includes("/rest/v1/")
      ? JSON.parse(init.body)
      : undefined;
    calls.push({ path, init, body });
    if (path.endsWith("/auth/v1/user")) {
      return json({ id: user }, options.auth === false ? 401 : 200);
    }
    if (path.includes("/rest/v1/")) {
      if (options.databaseFailure && path.includes(options.databaseFailure)) {
        return json({ secret: "private-database-canary" }, 500);
      }
      if (path.includes("documents?")) {
        return json(
          options.document === false ? [] : [{
            id: documentId,
            user_id: options.owner ?? user,
            file_path: options.path ?? `${user}/${documentId}/synthetic.pdf`,
            name: "Synthetic.pdf",
          }],
        );
      }
      if (path.endsWith("rpc/begin_document_processing")) {
        return json(
          options.claim ??
            {
              job_id: "job-one",
              lease_token: "private-lease",
              claimed: true,
              status: "running",
            },
        );
      }
      if (path.endsWith("rpc/get_document_processor_runtime")) {
        if (options.runtimeFailure) throw new Error("private-runtime-canary");
        return json(
          options.configured === false ? [] : [{
            provider_slug: "synthetic-ocr",
            endpoint_url: options.endpoint ?? "https://ocr.example.com/process",
            api_key: "synthetic-provider-canary",
            max_file_bytes: 1024,
            timeout_ms: 1000,
          }],
        );
      }
      if (path.endsWith("rpc/complete_document_processing")) {
        return json({
          extraction_id: "extraction-one",
          status: "review_required",
        });
      }
      return json(null);
    }
    if (path.includes("/storage/v1/")) {
      if (options.fileRedirect) {
        return new Response(null, {
          status: 302,
          headers: { location: "https://private.example.com" },
        });
      }
      return new Response(
        new Uint8Array(
          options.file ??
            new TextEncoder().encode("%PDF-1.4\nsynthetic fixture only"),
        ).buffer,
        {
          headers: {
            "content-type": options.mime ?? "application/pdf",
            ...(options.fileLength
              ? { "content-length": String(options.fileLength) }
              : {}),
          },
        },
      );
    }
    if (options.providerError) throw options.providerError;
    return json(
      options.providerBody ??
        {
          text: "متن ساختگی",
          language_code: "fa",
          confidence: 4,
          page_count: 1,
          fields: [{
            key: "synthetic_name",
            value: "Synthetic User",
            confidence: -1,
            page_number: 1,
          }, null],
        },
      options.providerStatus ?? 200,
    );
  };
  const handler = createDocumentHandler({
    url: "https://db.example.com",
    serviceKey: "synthetic-service-canary",
    fetch: fetcher,
  });
  const response = await handler(
    new Request("https://edge.example.com/process", {
      method,
      headers: {
        ...(authenticated
          ? { Authorization: "Bearer synthetic-user-canary" }
          : {}),
        "Content-Type": "application/json",
      },
      ...(method === "POST" ? { body: JSON.stringify(requestBody) } : {}),
    }),
  );
  const body = method === "OPTIONS"
    ? await response.text()
    : await response.json();
  return { status: response.status, body, calls };
}

Deno.test("OCR: successful synthetic file stays owner-bound and requires human review", async () => {
  const x = await exercise();
  equal(x.status, 200);
  equal(x.body, {
    job_id: "job-one",
    extraction_id: "extraction-one",
    status: "review_required",
    field_count: 1,
  });
  const extraction =
    x.calls.find((c) => c.path.endsWith("rpc/complete_document_processing"))!
      .body.p_extraction;
  equal(extraction.input_sha256.length, 64);
  equal(
    x.calls.find((c) => c.path.endsWith("rpc/begin_document_processing"))!.body
      .p_user_id,
    user,
  );
  equal(extraction.extracted_text, "متن ساختگی");
  equal(extraction.overall_confidence, 1);
  const fields =
    x.calls.find((c) => c.path.endsWith("rpc/complete_document_processing"))!
      .body.p_fields;
  equal(fields[0].confidence, 0);
  equal(fields[0].review_status, "unreviewed");
  const provider = x.calls.find((c) =>
    c.path.startsWith("https://ocr.example.com")
  )!;
  equal(provider.init?.redirect, "manual");
  equal(
    new Headers(provider.init?.headers).get("Authorization"),
    "Bearer synthetic-provider-canary",
  );
  equal(JSON.stringify(x.body).includes("canary"), false);
});

Deno.test("OCR: OPTIONS and wrong methods do not contact Auth or providers", async () => {
  for (const method of ["OPTIONS", "GET"]) {
    const x = await exercise({}, {}, method);
    equal(x.status, method === "OPTIONS" ? 200 : 405);
    equal(x.calls.length, 0);
  }
});

Deno.test("OCR: missing and invalid authentication cannot access documents", async () => {
  for (
    const [options, authenticated] of [[{}, false], [
      { auth: false },
      true,
    ]] as const
  ) {
    const x = await exercise(options, {}, "POST", authenticated);
    equal(x.status, 401);
    equal(x.calls.some((c) => c.path.includes("/rest/v1/")), false);
  }
});

Deno.test("OCR: malformed document identifiers fail before database calls", async () => {
  for (
    const body of [null, [], {}, { document_id: "not-a-uuid" }, {
      document_id: 42,
    }]
  ) {
    const x = await exercise({}, body);
    equal(x.status, 400);
    equal(x.calls.some((c) => c.path.includes("/rest/v1/")), false);
  }
});

Deno.test("OCR: request size is bounded before processing", async () => {
  const x = await exercise({}, {
    document_id: documentId,
    excess: "a".repeat(9000),
  });
  equal(x.status, 413);
  equal(x.calls.some((c) => c.path.includes("/rest/v1/")), false);
});

Deno.test("OCR: missing and cross-owner documents cannot create processing jobs", async () => {
  for (const options of [{ document: false }, { owner: "other-user" }]) {
    const x = await exercise(options);
    equal([403, 404].includes(x.status), true);
    equal(
      x.calls.some((c) => c.path.includes("document_processing_jobs")),
      false,
    );
  }
});

Deno.test("OCR: traversal, encoded traversal and foreign paths never reach Storage", async () => {
  for (
    const path of [
      `other/${documentId}/file.pdf`,
      `${user}/../file.pdf`,
      `${user}/%2e%2e/file.pdf`,
      `${user}/folder\\file.pdf`,
      `${user}//file.pdf`,
    ]
  ) {
    const x = await exercise({ path });
    equal(x.status, 403);
    equal(x.calls.some((c) => c.path.includes("/storage/v1/")), false);
  }
});

Deno.test("OCR: no configured provider fails honestly without sending a document", async () => {
  const x = await exercise({ configured: false });
  equal(x.status, 503);
  equal(x.body.code, "no_ocr_provider_configured");
  equal(x.calls.some((c) => c.path.includes("/storage/v1/")), false);
  equal(x.calls.at(-1)!.body.p_error_code, "no_ocr_provider_configured");
});

Deno.test("OCR: private, literal-IP and credential-bearing endpoints fail before file retrieval", async () => {
  for (
    const endpoint of [
      "http://ocr.example.com",
      "https://127.0.0.1",
      "https://2130706433",
      "https://[::ffff:127.0.0.1]",
      "https://metadata.google.internal",
      "https://name:secret@example.com",
      "https://localhost.",
    ]
  ) {
    const x = await exercise({ endpoint });
    equal(x.body.code, "invalid_ocr_configuration");
    equal(x.calls.some((c) => c.path.includes("/storage/v1/")), false);
  }
});

Deno.test("OCR: Storage redirects never forward the service credential", async () => {
  const x = await exercise({ fileRedirect: true });
  equal(x.body.code, "storage_redirect_forbidden");
  equal(x.calls.some((c) => c.path.startsWith("https://ocr.")), false);
  equal(
    x.calls.find((c) => c.path.includes("/storage/v1/"))!.init?.redirect,
    "manual",
  );
});

Deno.test("OCR: declared and streamed oversize files are rejected before provider access", async () => {
  for (
    const options of [{ fileLength: 10000 }, { file: new Uint8Array(2048) }]
  ) {
    const x = await exercise(options);
    equal(x.body.code, "file_too_large");
    equal(x.calls.some((c) => c.path.startsWith("https://ocr.")), false);
  }
});

Deno.test("OCR: MIME and file signatures must both match accepted types", async () => {
  for (
    const options of [{ mime: "text/html" }, {
      file: new TextEncoder().encode("html disguised as a PDF"),
    }]
  ) {
    const x = await exercise(options);
    equal(
      ["unsupported_file_type", "invalid_file_signature"].includes(x.body.code),
      true,
    );
    equal(x.calls.some((c) => c.path.startsWith("https://ocr.")), false);
  }
});

Deno.test("OCR: PNG and JPEG fixtures use their declared allowed MIME", async () => {
  for (
    const [mime, bytes] of [["image/png", [137, 80, 78, 71, 13, 10, 26, 10]], [
      "image/jpeg",
      [255, 216, 255],
    ]] as const
  ) {
    const x = await exercise({ mime, file: new Uint8Array(bytes) });
    equal(x.status, 200);
  }
});

Deno.test("OCR: provider redirects do not produce extractions or follow another origin", async () => {
  const x = await exercise({ providerStatus: 307 });
  equal(x.body.code, "provider_redirect_forbidden");
  equal(x.calls.some((c) => c.path.includes("document_extractions")), false);
});

Deno.test("OCR: upstream text and thrown secrets never appear in responses or audit updates", async () => {
  for (
    const options of [
      {
        providerStatus: 500,
        providerBody: { error: "private-provider-canary" },
      },
      { providerError: new Error("private-provider-canary") },
      { runtimeFailure: true },
    ]
  ) {
    const x = await exercise(options);
    equal(
      JSON.stringify([
        x.body,
        x.calls.filter((c) => c.path.endsWith("rpc/fail_document_processing"))
          .map((c) => c.body),
      ]).includes("canary"),
      false,
    );
    equal(x.calls.at(-1)!.path.endsWith("rpc/fail_document_processing"), true);
  }
});

Deno.test("OCR: provider timeout is a fixed failure with no extraction", async () => {
  const x = await exercise({
    providerError: new DOMException("private-timeout-canary", "TimeoutError"),
  });
  equal(x.body.code, "provider_timeout");
  equal(x.calls.some((c) => c.path.includes("document_extractions")), false);
});

Deno.test("OCR: empty, malformed and oversized provider output cannot become reviewed evidence", async () => {
  for (
    const providerBody of [null, [], { text: "" }, {
      text: "a".repeat(1_000_001),
    }]
  ) {
    const x = await exercise({
      providerBody: providerBody === null
        ? "not a structured OCR object"
        : providerBody,
    });
    equal(
      ["provider_malformed_response", "provider_response_too_large"].includes(
        x.body.code,
      ),
      true,
    );
    equal(x.calls.some((c) => c.path.includes("document_extractions")), false);
  }
});

Deno.test("OCR: database failures and failed audit writes never expose backend diagnostics", async () => {
  for (
    const databaseFailure of [
      "documents?",
      "complete_document_processing",
      "begin_document_processing",
    ]
  ) {
    const x = await exercise({ databaseFailure });
    equal(x.status, 503);
    equal(x.body.code, "database_unavailable");
    equal(JSON.stringify(x.body).includes("canary"), false);
  }
});

Deno.test("OCR: active claims and rate limits never repeat provider processing", async () => {
  for (
    const [claim, status] of [[{
      claimed: false,
      status: "running",
      job_id: "existing-job",
    }, 202], [{ claimed: false, status: "rate_limited" }, 429]] as const
  ) {
    const x = await exercise({ claim });
    equal(x.status, status);
    equal(
      x.calls.some((c) =>
        c.path.includes("/storage/v1/") || c.path.startsWith("https://ocr.")
      ),
      false,
    );
    equal(JSON.stringify(x.body).includes("lease"), false);
  }
});
Deno.test("OCR: atomic completion and failure use only the private claim token", async () => {
  const x = await exercise({ databaseFailure: "complete_document_processing" });
  equal(x.status, 503);
  equal(
    x.calls.some((c) =>
      c.path.includes("document_extractions?") ||
      c.path.endsWith("document_fields")
    ),
    false,
  );
  equal(x.calls.at(-1)!.body.p_lease_token, "private-lease");
  equal(JSON.stringify(x.body).includes("private-lease"), false);
});
Deno.test("OCR: configured credential echoes cannot enter persisted extraction fields", async () => {
  const x = await exercise({
    providerBody: { text: "synthetic-provider-canary", fields: [] },
  });
  equal(x.body.code, "provider_malformed_response");
  equal(
    x.calls.some((c) => c.path.endsWith("rpc/complete_document_processing")),
    false,
  );
});
