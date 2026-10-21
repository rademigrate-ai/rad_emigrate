// deno-lint-ignore no-unversioned-import
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handler } from "./handler.ts";

Deno.serve(handler);
