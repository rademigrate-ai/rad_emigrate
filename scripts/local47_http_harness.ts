/** Test-only loopback server. This file is not an Edge deployment entrypoint. */
import { handler as paymentHandler } from "../supabase/functions/payment-sandbox/handler.ts";
import { dispatchSandboxNotifications } from "../supabase/functions/notification-dispatch/worker.ts";
import { createDocumentHandler } from "../supabase/functions/document-intelligence/handler.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const token = Deno.env.get("RAD_LOCAL47_TEST_TOKEN")!;
const port = Number(Deno.env.get("RAD_LOCAL47_TEST_PORT"));
if (
  new URL(url).hostname !== "127.0.0.1" || !token || !Number.isInteger(port)
) throw new Error("local_harness_configuration");
let releaseOcr: (() => void) | undefined;
let ocrStarted = false;
let ocrCalls = 0;
const ocrBarrier = new Promise<void>((resolve) => {
  releaseOcr = resolve;
});
const documentHandler = createDocumentHandler({
  url,
  serviceKey: key,
  fetch: async (input, init) => {
    if (String(input) === "https://ocr-fixture.example.com/process") {
      ocrCalls++;
      ocrStarted = true;
      await ocrBarrier;
      return Response.json({
        text: "Synthetic local fixture text",
        language_code: "en",
        confidence: 0.9,
        fields: [{
          key: "synthetic_name",
          value: "Synthetic fixture",
          page_number: 1,
          confidence: 0.9,
        }],
      });
    }
    return await fetch(input, init);
  },
});
Deno.serve({ hostname: "127.0.0.1", port }, async (req) => {
  const path = new URL(req.url).pathname;
  if (path === "/payment") return await paymentHandler(req);
  if (path === "/documents" || path === "/ocr-control") {
    if (req.headers.get("x-rad-local-test-token") !== token) {
      return Response.json({ error: "forbidden" }, { status: 403 });
    }
    if (path === "/documents") return await documentHandler(req);
    if (req.method === "POST") releaseOcr?.();
    return Response.json({ ocr_started: ocrStarted, ocr_calls: ocrCalls });
  }
  if (path !== "/notifications" || req.method !== "POST") {
    return Response.json({ error: "not_found" }, { status: 404 });
  }
  if (req.headers.get("x-rad-local-test-token") !== token) {
    return Response.json({ error: "forbidden" }, { status: 403 });
  }
  try {
    const result = await dispatchSandboxNotifications(
      async (path, init) => {
        const response = await fetch(`${url}/rest/v1/${path}`, {
          ...init,
          redirect: "error",
          signal: AbortSignal.timeout(10000),
          headers: {
            apikey: key,
            Authorization: `Bearer ${key}`,
            "Content-Type": "application/json",
          },
        });
        if (!response.ok) throw new Error("local_database_unavailable");
        return await response.json();
      },
      async () => {},
      10,
    ); // a synthetic in-memory receipt, never a real transport
    return Response.json(result);
  } catch {
    return Response.json({ error: "local_dispatch_unavailable" }, {
      status: 503,
    });
  }
});
