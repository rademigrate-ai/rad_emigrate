/** Local-only acceptance launcher. It cannot contact public networks. */
import { workerDatabase } from "../../_shared/purpose_worker.ts";
import { createOfficialSourceHandler } from "../../official-source-worker/handler.ts";
import { createOfficialDispatcher } from "../../official-source-worker/dispatcher.ts";
import { createBoundOfficialRefresh } from "../../official-source-worker/refresh.ts";
import { createResearchEgressFetch } from "../../research-sync/egress.ts";

const api = Deno.env.get("RAD_ACCEPTANCE_API") ?? "";
const port = Number(Deno.env.get("RAD_ACCEPTANCE_WORKER_PORT"));
if (
  !/^http:\/\/127\.0\.0\.1:[0-9]+$/.test(api) || !Number.isInteger(port) ||
  port < 1024
) {
  throw Error("explicit_loopback_acceptance_configuration_required");
}
const database = workerDatabase(api, "synthetic-native-service-key");
const token = "synthetic-native-official-worker-token-00000000";
const transport = createResearchEgressFetch({
  url: "https://fixture-gateway.example.invalid/fetch",
  token: "synthetic-native-egress-purpose-token-00000000",
  fetch: (url, init) => {
    if (String(url) !== "https://fixture-gateway.example.invalid/fetch") {
      throw Error("unexpected_fixture_gateway");
    }
    return fetch(`${api}/fetch`, init);
  },
});
const worker = createOfficialSourceHandler({
  enabled: true,
  token,
  chunked: true,
  database,
  refresh: createBoundOfficialRefresh(database, transport),
});
const dispatch = createOfficialDispatcher({
  enabled: true,
  token,
  database,
  worker,
});
Deno.serve(
  { hostname: "127.0.0.1", port },
  (request) =>
    new URL(request.url).searchParams.get("dispatch") === "1"
      ? dispatch(request)
      : worker(request),
);
