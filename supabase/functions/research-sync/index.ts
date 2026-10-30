import { createResearchHandler } from "./handler.ts";
import { createResearchEgressFetch } from "./egress.ts";

// Production always registers the handler; tests import handler.ts directly.
Deno.serve(createResearchHandler({
  sourceFetch: createResearchEgressFetch({
    url: Deno.env.get("RAD_RESEARCH_EGRESS_URL") ?? "",
    token: Deno.env.get("RAD_RESEARCH_EGRESS_TOKEN") ?? "",
  }),
}));
