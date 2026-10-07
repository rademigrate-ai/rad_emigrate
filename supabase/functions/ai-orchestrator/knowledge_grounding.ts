/** Stage 4 Knowledge grounding — approved retrieve_knowledge only; never trust inventory/REVIEW_REQUIRED. */
export type Source = {
  title: string;
  url: string;
  authority: string;
  retrieved_at?: string;
  excerpt?: string;
  claim_label?: string;
};

type DbFn = (path: string, init?: RequestInit) => Promise<any>;

function detectLocale(queryHint?: string): string {
  const q = queryHint ?? "";
  if (/[\u0600-\u06FF]/.test(q)) return "fa";
  return "en";
}

/** Canonical grounding: approved Knowledge only. Stage 3 inventory never trusted. */
export async function loadGrounding(
  db: DbFn,
  scope: "user" | "admin",
  queryHint?: string,
  localeHint?: string,
): Promise<{ text: string; sources: Source[]; locale: string; hasApprovedEvidence: boolean }> {
  const sources: Source[] = [];
  const excerpts: string[] = [];
  const locale = localeHint === "fa" || localeHint === "en" ? localeHint : detectLocale(queryHint);
  let usedRpc = false;
  let hasApprovedEvidence = false;

  try {
    const payload = await db("rpc/retrieve_knowledge", {
      method: "POST",
      body: JSON.stringify({
        p_query: (queryHint ?? "").slice(0, 500),
        p_locale: locale,
        p_destination_code: null,
        p_program_slug: null,
        p_limit: 8,
      }),
    });
    const results = Array.isArray(payload?.results) ? payload.results : [];
    if (results.length > 0) {
      usedRpc = true;
      for (const item of results) {
        const itemStatus = item?.review_status ?? item?.status;
        if (itemStatus && itemStatus !== "approved") continue;
        if (item?.title) {
          excerpts.push(`[APPROVED] ${item.title}: ${item.summary ?? ""}`);
          hasApprovedEvidence = true;
        }
        for (const claim of item?.claims ?? []) {
          const claimStatus = claim?.review_status ?? "approved";
          if (claimStatus === "conflicting") {
            excerpts.push(`[CONFLICT — do not resolve unilaterally] ${claim.claim_text}`);
            hasApprovedEvidence = true;
            continue;
          }
          if (claimStatus && claimStatus !== "approved") continue;
          if (claim?.claim_text) {
            excerpts.push(`[APPROVED CLAIM] ${claim.claim_text}`);
            hasApprovedEvidence = true;
          }
          for (const citation of claim?.citations ?? []) {
            const src = citation?.source;
            if (src?.canonical_url) {
              sources.push({
                title: src.title ?? item.title,
                url: src.canonical_url,
                authority: src.source_authority ?? "other",
                retrieved_at: citation.fetched_at,
                excerpt: citation.excerpt,
                claim_label: claim?.claim_text ? String(claim.claim_text).slice(0, 120) : undefined,
              });
            }
          }
        }
        for (const conf of item?.open_conflicts ?? []) {
          excerpts.push(
            `[OPEN CONFLICT] A: ${conf.statement_a ?? conf.claim_a ?? ""} | B: ${conf.statement_b ?? conf.claim_b ?? ""}`,
          );
        }
      }
    }
  } catch {
    // RPC unavailable — approved-items fallback only
  }

  if (!usedRpc) {
    const approved = await db(
      "knowledge_items?select=id,title,summary,review_status,knowledge_claims(claim_text,review_status,knowledge_citations(excerpt,source_snapshots(fetched_at,source_documents(title,canonical_url,source_authority))))&review_status=eq.approved&order=updated_at.desc&limit=6",
    );
    for (const item of approved ?? []) {
      if (item.review_status && item.review_status !== "approved") continue;
      excerpts.push(`[APPROVED] ${item.title}: ${item.summary ?? ""}`);
      hasApprovedEvidence = true;
      for (const claim of item.knowledge_claims ?? []) {
        if (claim.review_status && claim.review_status !== "approved") continue;
        if (claim.claim_text) excerpts.push(`[APPROVED CLAIM] ${claim.claim_text}`);
        for (const citation of claim.knowledge_citations ?? []) {
          const doc = citation?.source_snapshots?.source_documents;
          if (doc?.canonical_url) {
            sources.push({
              title: doc.title ?? item.title,
              url: doc.canonical_url,
              authority: doc.source_authority ?? "other",
              retrieved_at: citation?.source_snapshots?.fetched_at,
              excerpt: citation.excerpt,
              claim_label: claim.claim_text ? String(claim.claim_text).slice(0, 120) : undefined,
            });
          }
        }
      }
    }
  }

  const seen = new Set<string>();
  const uniqueSources = sources.filter((s) => {
    if (!s.url || seen.has(s.url)) return false;
    seen.add(s.url);
    return true;
  });

  const header =
    scope === "admin"
      ? "ADMIN RESEARCH CONTEXT — approved Knowledge only; preserve disagreements; never invent."
      : "USER AI GROUNDING — approved/current Knowledge only. Unverified website inventory is NOT included.";

  const body = excerpts.length
    ? excerpts.slice(0, 40).join("\n")
    : "No approved Knowledge evidence matched this query. Do not invent immigration requirements, fees, eligibility, or timelines.";

  return {
    text: `${header}\n${body}`,
    sources: uniqueSources.slice(0, 12),
    locale,
    hasApprovedEvidence,
  };
}
