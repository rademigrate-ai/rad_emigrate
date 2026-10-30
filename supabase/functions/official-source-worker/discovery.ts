import { isSafePublicHttpsUrl } from "../_shared/public_url.ts";
import {
  performWebSearch,
  type WebSearchResult,
} from "../ai-orchestrator/web_search.ts";

type Scope = { country_code: string; topic: string; profession: string | null };
type Search = (query: string) => Promise<WebSearchResult>;

/** Search is discovery only: it cannot establish authority or verify a claim. */
export function createAuthorityDiscovery(search: Search = performWebSearch) {
  return async (scope: Scope): Promise<{ name: string; url: string }[]> => {
    // The lease supplies validated scope, never user messages or private files.
    const clean = (value: string) =>
      value.replace(/[^\p{L}\p{N} _-]/gu, " ").trim();
    const country = clean(scope.country_code).slice(0, 2);
    const topic = clean(scope.topic).slice(0, 60);
    const profession = clean(scope.profession ?? "").slice(0, 60);
    if (!/^[A-Z]{2}$/.test(country) || !topic) {
      throw new Error("invalid_discovery_scope");
    }
    const query =
      `${country} ${topic} ${profession} official government immigration university admissions authority`
        .slice(0, 300);
    const found = await search(query);
    if (found.status !== "ok" && found.status !== "empty") {
      throw new Error("discovery_unavailable");
    }
    return found.citations.slice(0, 20)
      .filter((item) => item.title.trim() && isSafePublicHttpsUrl(item.url))
      .map((item) => ({
        name: item.title.trim().slice(0, 300),
        url: item.url,
      }));
  };
}
