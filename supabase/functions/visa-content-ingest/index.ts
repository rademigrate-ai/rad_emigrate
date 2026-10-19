import { workerDatabase } from "../_shared/purpose_worker.ts";
import { createVisaIngestHandler } from "./handler.ts";
Deno.serve(createVisaIngestHandler({
  enabled: Deno.env.get("RAD_CONTENT_INGEST_ENABLED") === "true",
  token: Deno.env.get("RAD_CONTENT_WORKER_TOKEN") ?? "",
  database: workerDatabase(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  ),
}));
