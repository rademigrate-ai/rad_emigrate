import { workerDatabase } from "../_shared/purpose_worker.ts";
import { createOfficialSourceHandler } from "./handler.ts";
// Discovery adapter/search-provider and protected egress activation require
// reviewed infrastructure. Unconfigured jobs fail explicitly, never fake proof.
Deno.serve(createOfficialSourceHandler({
  enabled: Deno.env.get("RAD_OFFICIAL_SOURCE_WORKER_ENABLED") === "true",
  token: Deno.env.get("RAD_OFFICIAL_SOURCE_WORKER_TOKEN") ?? "",
  database: workerDatabase(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  ),
}));
