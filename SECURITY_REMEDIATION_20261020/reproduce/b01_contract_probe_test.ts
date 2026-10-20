import { handler } from "../rad_security_verify_b01f625/supabase/functions/ai-orchestrator/handler.ts";
import { contractValid } from "../rad_security_verify_b01f625/supabase/functions/_shared/rad_contract.ts";

Deno.test("published Flutter version is rejected by actual Edge dispatcher", async () => {
  const source = await Deno.readTextFile(new URL("../rad_security_verify_b01f625/lib/core/services/ai/supabase_ai_service.dart", import.meta.url));
  const version = /'x-rad-contract-version':\s*'([^']+)'/.exec(source)?.[1];
  if (!version) throw new Error("client_version_not_found");
  const response = await handler(new Request("http://localhost/ai-orchestrator", {
    method: "POST", headers: { "x-rad-contract-version": version }, body: "{}",
  }));
  const body = await response.json();
  if (response.status !== 422 || body.error !== "unsupported_contract_version") throw new Error("observed_mismatch_changed");
  // A passing observation confirms the integration defect, not AI readiness.
});

Deno.test("documented numeric version reaches body validation without network", async () => {
  const response = await handler(new Request("http://localhost/ai-orchestrator", {
    method: "POST", headers: { "x-rad-contract-version": "1" }, body: "{}",
  }));
  const body = await response.json();
  if (response.status !== 422 || body.error !== "invalid_request") throw new Error("control_dispatch_changed");
});

Deno.test("timestamp default cannot satisfy UUID idempotency contract", async () => {
  const source = await Deno.readTextFile(new URL("../rad_security_verify_b01f625/lib/core/services/ai/supabase_ai_service.dart", import.meta.url));
  if (!source.includes("'ai-${DateTime.now().toUtc().microsecondsSinceEpoch}'")) throw new Error("client_default_changed");
  if (contractValid("UUID", "ai-1792526400000000")) throw new Error("UUID_contract_broken");
});
