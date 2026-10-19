import { createCurrencyHandler } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL") ?? "";
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
Deno.serve(createCurrencyHandler({
  enabled: Deno.env.get("RAD_CURRENCY_REFRESH_ENABLED") === "true",
  token: Deno.env.get("RAD_CURRENCY_WORKER_TOKEN") ?? "",
  database: async (path, init) => {
    const response = await fetch(`${url}/rest/v1/${path}`, {
      ...init,
      signal: AbortSignal.timeout(10000),
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
    });
    if (!response.ok) throw new Error("cache_write_failed");
    return response.json();
  },
}));
