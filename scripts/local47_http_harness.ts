/** Test-only loopback server. This file is not an Edge deployment entrypoint. */
import { handler as paymentHandler } from "../supabase/functions/payment-sandbox/handler.ts";
import { dispatchSandboxNotifications } from "../supabase/functions/notification-dispatch/worker.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const token = Deno.env.get("RAD_LOCAL47_TEST_TOKEN")!;
const port = Number(Deno.env.get("RAD_LOCAL47_TEST_PORT"));
if (
  new URL(url).hostname !== "127.0.0.1" || !token || !Number.isInteger(port)
) throw new Error("local_harness_configuration");
Deno.serve({ hostname: "127.0.0.1", port }, async (req) => {
  const path = new URL(req.url).pathname;
  if (path === "/payment") return await paymentHandler(req);
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
