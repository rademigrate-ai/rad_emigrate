import { isSafePublicHttpsUrl } from "../_shared/public_url.ts";
import type { WorkerDb } from "../_shared/purpose_worker.ts";
type SourceFetch = (url: string, init: RequestInit) => Promise<Response>;
type Lease = { job_id: string; lease_token: string };
type Target = {
  binding_id: string;
  url: string;
  expected_revision_id: string;
  expected_snapshot_id: string;
  verified_path_prefix: string;
};

function insideVerifiedPath(
  value: string,
  host: string,
  prefix: string,
): boolean {
  if (
    typeof prefix !== "string" || !prefix.startsWith("/") ||
    /[?#\s\\]/.test(prefix)
  ) return false;
  if (!isSafePublicHttpsUrl(value) || /[\s\\#]/.test(value)) return false;
  const parsed = new URL(value);
  if (parsed.hostname !== host || !["", "443"].includes(parsed.port)) {
    return false;
  }
  const rawPath = value.match(/^https:\/\/[^/?#]+([^?#]*)/)?.[1] || "/";
  const unsafe =
    /(?:^|\/)\.{1,2}(?:\/|$)|%(?:2e|2f|5c|25|0[0-9a-f]|1[0-9a-f]|20|7f)|%(?![0-9a-f]{2})/i;
  if (unsafe.test(rawPath) || unsafe.test(prefix)) return false;
  const base = prefix.replace(/\/+$/, "");
  return base === "" || rawPath === base || rawPath.startsWith(base + "/");
}

/** Fetch only explicit Admin-bound sources. No translation, extraction model,
 * inferred article mapping or publication. The database extracts exact markers
 * and owns atomic snapshot/fragment comparison and structured review proposals.
 */
export function createBoundOfficialRefresh(
  database: WorkerDb,
  sourceFetch?: SourceFetch,
) {
  if (!sourceFetch) return undefined;
  return async (
    lease: Lease,
  ): Promise<{ complete: boolean; processed: number }> => {
    const leaseRequest = {
      method: "POST",
      body: JSON.stringify({
        p_job_id: lease.job_id,
        p_lease_token: lease.lease_token,
      }),
    };
    const targets = await database("rpc/get_bound_official_refresh_targets", {
      method: "POST",
      body: JSON.stringify({
        p_job_id: lease.job_id,
        p_lease_token: lease.lease_token,
      }),
    }) as Target[];
    if (!Array.isArray(targets) || targets.length > 20) {
      throw Error("explicit_source_bindings_required");
    }
    if (!targets.length) return { complete: true, processed: 0 };
    // One source per invocation. Durable progress permits the same job to yield
    // and resume without exhausting failure attempts or re-fetching old targets.
    for (const target of targets.slice(0, 1)) {
      let current = target.url;
      const initial = new URL(target.url);
      let finalResponse: Response | undefined;
      for (let hop = 0; hop <= 3; hop++) {
        const parsed = new URL(current);
        if (
          !insideVerifiedPath(
            current,
            initial.hostname,
            target.verified_path_prefix,
          ) ||
          parsed.hostname !== initial.hostname
        ) throw Error("unsafe_source_url");
        await database("rpc/renew_bound_official_refresh_lease", leaseRequest);
        const response = await sourceFetch(current, {
          redirect: "manual",
          signal: AbortSignal.timeout(12000),
          headers: { Accept: "text/html,text/plain;q=0.9" },
        });
        if (response.status >= 300 && response.status < 400) {
          const location = response.headers.get("location");
          await response.body?.cancel();
          if (!location || hop === 3) throw Error("unsafe_source_redirect");
          // Check the raw redirect before URL canonicalization can erase dot
          // segments. The normalized destination must remain under the proof.
          if (/(?:^|\/)\.{1,2}(?:\/|$)|%(?:2e|2f|5c|25)/i.test(location)) {
            throw Error("unsafe_source_redirect");
          }
          current = new URL(location, current).href;
          continue;
        }
        finalResponse = response;
        break;
      }
      if (!finalResponse || finalResponse.status !== 200) {
        throw Error("source_unavailable");
      }
      const media = (finalResponse.headers.get("content-type") ?? "").split(
        ";",
      )[0].trim().toLowerCase();
      if (
        !["text/html", "text/plain", "application/xhtml+xml"].includes(media)
      ) throw Error("unsupported_source_type");
      const length = Number(finalResponse.headers.get("content-length"));
      if (Number.isFinite(length) && length > 1_000_000) {
        await finalResponse.body?.cancel();
        throw Error("source_too_large");
      }
      const reader = finalResponse.body?.getReader();
      if (!reader) throw Error("source_empty");
      const chunks: Uint8Array[] = [];
      let size = 0;
      try {
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          size += value.byteLength;
          if (size > 1_000_000) throw Error("source_too_large");
          chunks.push(value);
        }
      } finally {
        await reader.cancel().catch(() => undefined);
      }
      const raw = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) {
        raw.set(chunk, offset);
        offset += chunk.byteLength;
      }
      const text = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true })
        .decode(raw);
      const normalized = media === "text/plain"
        ? text.trim()
        : text.replace(/<script[\s\S]*?<\/script>/gi, " ").replace(
          /<style[\s\S]*?<\/style>/gi,
          " ",
        ).replace(/<!--[\s\S]*?-->/g, " ").replace(/<[^>]+>/g, " ").replace(
          /&nbsp;|&#160;/gi,
          " ",
        ).replace(/&amp;/gi, "&").replace(/\s+/g, " ").trim();
      if (!normalized || normalized.length > 100000) {
        throw Error("source_text_out_of_bounds");
      }
      let binary = "";
      for (let start = 0; start < raw.length; start += 8192) {
        binary += String.fromCharCode(...raw.subarray(start, start + 8192));
      }
      await database("rpc/renew_bound_official_refresh_lease", leaseRequest);
      await database("rpc/ingest_bound_official_refresh", {
        method: "POST",
        body: JSON.stringify({
          p_job_id: lease.job_id,
          p_lease_token: lease.lease_token,
          p_binding_id: target.binding_id,
          p_expected_revision_id: target.expected_revision_id,
          p_expected_snapshot_id: target.expected_snapshot_id,
          p_normalized_text: normalized,
          p_raw_base64: btoa(binary),
          p_final_url: current,
          p_http_status: 200,
        }),
      });
    }
    const remaining = await database(
      "rpc/get_bound_official_refresh_targets",
      leaseRequest,
    ) as Target[];
    if (!Array.isArray(remaining)) throw Error("invalid_target_manifest");
    return { complete: remaining.length === 0, processed: 1 };
  };
}
