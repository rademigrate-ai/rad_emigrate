import { handler } from "./handler.ts";

// Production always registers the handler; tests import handler.ts directly.
Deno.serve(handler);
