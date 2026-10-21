import { handler as ai } from "../ai-orchestrator/handler.ts";
import { handler as research } from "../research-sync/handler.ts";
import { handler as document } from "../document-intelligence/handler.ts";
import { handler as notifications } from "../notification-dispatch/handler.ts";
import { handler as payment } from "../payment-sandbox/handler.ts";

// Exercise the real entry handlers. Preflight must not need Auth, quota, database,
// or any provider network call (the test runner grants no network permission).
for (const [name, handler] of Object.entries({ ai, research, document, notifications, payment })) {
  Deno.test(`${name}: browser preflight permits the complete RAD client contract`, async () => {
    const required = ["authorization", "apikey", "content-type", "x-client-info",
      "x-rad-contract-version", "x-rad-request-key", "x-rad-modality"];
    const response = await handler(new Request("https://example.invalid/functions/v1/test", {
      method: "OPTIONS",
      headers: { Origin: "https://rad-audit.invalid", "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": required.join(", ") },
    }));
    if (response.status !== 200) throw new Error(`Preflight status: ${response.status}`);
    const allowed = response.headers.get("Access-Control-Allow-Headers")?.toLowerCase().split(",").map((h) => h.trim()) ?? [];
    for (const header of required) {
      if (!allowed.includes(header)) throw new Error(`Preflight rejected ${header}`);
    }
    if (!response.headers.get("Access-Control-Allow-Methods")?.includes("POST")) throw new Error("POST not allowed");
    if (response.headers.get("Access-Control-Allow-Credentials") === "true") throw new Error("Wildcard credentialed CORS");
    await response.body?.cancel();
  });
}
