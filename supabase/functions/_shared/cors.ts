// Browser clients send x-client-info when invoking Supabase Edge Functions.
// Keep the wildcard origin: these functions use explicit JWT/API-key
// authorization, do not use credentialed cookies, and serve the public web app.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export const researchCorsHeaders = {
  ...corsHeaders,
  "Access-Control-Allow-Headers": `${
    corsHeaders["Access-Control-Allow-Headers"]
  }, x-rad-research-token`,
};
