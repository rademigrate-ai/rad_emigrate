/**
 * Eight-hour model catalogue synchronization for enabled AI providers.
 * Distinct from continuous health monitoring (record_ai_provider_outcome).
 */

import {
  db,
  discover,
  providerRuntime,
  recordHealth,
  ProviderError,
  type ProviderRuntime,
} from "./handler_providers.ts";

export type SyncSummary = {
  provider_id: string;
  provider_slug?: string;
  status: "ok" | "failed" | "skipped";
  discovered?: number;
  error?: string;
};

export async function syncProviderCatalogue(
  providerId: string,
): Promise<SyncSummary> {
  let runtime: ProviderRuntime | undefined;
  try {
    runtime = await providerRuntime(providerId);
    const models = await discover(runtime);
    const summary = await db("rpc/ingest_ai_model_catalogue", {
      method: "POST",
      body: JSON.stringify({
        p_provider_id: providerId,
        p_credential_version: runtime.credential_version,
        p_models: models,
      }),
    }) as Record<string, unknown> | null;
    await recordHealth(runtime, undefined, true).catch(() => undefined);
    return {
      provider_id: providerId,
      provider_slug: runtime.provider_slug,
      status: "ok",
      discovered: Array.isArray(models) ? models.length : Number(summary?.discovered ?? 0),
    };
  } catch (error) {
    const code = error instanceof ProviderError ? error.code : "sync_failed";
    if (runtime) await recordHealth(runtime, code).catch(() => undefined);
    return {
      provider_id: providerId,
      provider_slug: runtime?.provider_slug,
      status: "failed",
      error: code,
    };
  }
}

/** Sync all enabled providers sequentially with bounded concurrency of 1 (avoid thundering herd). */
export async function syncAllEnabledProviderCatalogues(): Promise<{
  started_at: string;
  finished_at: string;
  results: SyncSummary[];
}> {
  const started_at = new Date().toISOString();
  const rows = await db(
    "ai_providers?select=id,slug,enabled&enabled=eq.true&order=priority.asc",
  ) as Array<{ id: string; slug: string }> | null;
  const results: SyncSummary[] = [];
  for (const row of rows ?? []) {
    if (!row?.id) continue;
    results.push(await syncProviderCatalogue(row.id));
  }
  return {
    started_at,
    finished_at: new Date().toISOString(),
    results,
  };
}
