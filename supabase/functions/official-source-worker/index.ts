import { createResearchEgressFetch } from "../research-sync/egress.ts";
import { createBoundOfficialRefresh } from "./refresh.ts";
import { workerDatabase } from "../_shared/purpose_worker.ts";
import { createOfficialSourceHandler } from "./handler.ts";
import { createAuthorityDiscovery } from "./discovery.ts";
import { createOfficialDispatcher } from "./dispatcher.ts";
// Candidate discovery uses the configured fixed-endpoint search adapter.
// Protected source refresh still requires reviewed egress infrastructure.
const enabled = Deno.env.get("RAD_OFFICIAL_SOURCE_WORKER_ENABLED") === "true";
const token = Deno.env.get("RAD_OFFICIAL_SOURCE_WORKER_TOKEN") ?? "";
const database = workerDatabase(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);
const legacyWorker = createOfficialSourceHandler({
  enabled,
  token,
  database,
  discover: createAuthorityDiscovery(),
});
const worker = createOfficialSourceHandler({
  enabled,
  token,
  chunked: true,
  discover: createAuthorityDiscovery(),
  refresh: createBoundOfficialRefresh(
    database,
    createResearchEgressFetch({
      url: Deno.env.get("RAD_RESEARCH_EGRESS_URL") ?? "",
      token: Deno.env.get("RAD_RESEARCH_EGRESS_TOKEN") ?? "",
    }),
  ),
  database,
});
const dispatch = createOfficialDispatcher({ enabled, token, database, worker });
Deno.serve((request) =>
  new URL(request.url).searchParams.get("dispatch") === "1"
    ? dispatch(request)
    : legacyWorker(request)
);
