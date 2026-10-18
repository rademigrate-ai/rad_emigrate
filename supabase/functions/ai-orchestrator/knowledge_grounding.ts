/** Approved, query-matched Knowledge only; retrieval content remains untrusted data. */
export type Source = {
  title: string;
  url: string;
  authority: string;
  retrieved_at?: string;
  excerpt?: string;
  claim_label?: string;
};

type DbFn = (path: string, init?: RequestInit) => Promise<unknown>;
type Row = Record<string, unknown>;

function row(value: unknown): Row {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Row : {};
}

function rows(value: unknown): Row[] {
  return Array.isArray(value) ? value.map(row) : [];
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function citationUrl(value: unknown): string | undefined {
  const raw = text(value);
  try {
    const url = new URL(raw);
    if (!["https:", "http:"].includes(url.protocol) || url.username || url.password) return;
    return url.href;
  } catch {
    return;
  }
}

/** Escape structural delimiters, not the meaning of retrieved text. This is not an injection detector. */
function escapeContext(value: string): string {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
}

/** A missing/unavailable retrieval result must never substitute unrelated recent Knowledge. */
export async function loadGrounding(
  db: DbFn,
  scope: "user" | "admin",
  queryHint?: string,
  localeHint?: string,
): Promise<{ text: string; sources: Source[]; locale: string; hasApprovedEvidence: boolean; hasConflicts: boolean }> {
  const sources: Source[] = [];
  const excerpts: string[] = [];
  const locale = localeHint === "fa" || localeHint === "en"
    ? localeHint : /[\u0600-\u06FF]/.test(queryHint ?? "") ? "fa" : "en";
  let hasApprovedEvidence = false;
  let hasConflicts = false;
  let results: Row[] = [];

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
    results = rows(row(payload).results).slice(0, 8);
  } catch {
    // Fail closed to insufficient evidence; do not expose database diagnostics.
  }

  for (const item of results) {
    if (item.review_status !== "approved") continue;
    const title = text(item.title);
    if (title) {
      excerpts.push(`[APPROVED] ${title}: ${text(item.summary)}`);
      hasApprovedEvidence = true;
    }
    for (const claim of rows(item.claims)) {
      if (claim.is_current !== true) continue;
      const claimText = text(claim.claim_text);
      if (!claimText) continue;
      if (claim.review_status === "conflicting") {
        excerpts.push(`[CONFLICT — do not resolve unilaterally] ${claimText}`);
        hasConflicts = true;
        continue;
      }
      if (claim.review_status !== "approved") continue;
      excerpts.push(`[APPROVED CLAIM] ${claimText}`);
      hasApprovedEvidence = true;
      for (const citation of rows(claim.citations)) {
        const src = row(citation.source);
        const url = citationUrl(src.canonical_url);
        if (!url) continue;
        sources.push({
          title: text(src.title) || title,
          url,
          authority: text(src.source_authority) || "other",
          retrieved_at: text(citation.fetched_at) || undefined,
          excerpt: text(citation.excerpt) || undefined,
          claim_label: claimText.slice(0, 120),
        });
      }
    }
    for (const conf of rows(item.open_conflicts)) {
      const a = text(conf.statement_a) || text(conf.claim_a);
      const b = text(conf.statement_b) || text(conf.claim_b);
      if (!a && !b) continue;
      excerpts.push(`[OPEN CONFLICT] A: ${a} | B: ${b}`);
      hasConflicts = true;
    }
  }

  const seen = new Set<string>();
  const uniqueSources = sources.filter((source) => {
    if (seen.has(source.url)) return false;
    seen.add(source.url);
    return true;
  });
  const header = scope === "admin"
    ? "ADMIN RESEARCH CONTEXT — approved Knowledge only; preserve disagreements; never invent."
    : "USER AI GROUNDING — approved/current Knowledge only. Unverified website inventory is NOT included.";
  const body = excerpts.length
    ? escapeContext(excerpts.slice(0, 40).join("\n"))
    : "No approved Knowledge evidence matched this query. Do not invent immigration requirements, fees, eligibility, or timelines.";

  return {
    text: `${header}\n${body}`,
    sources: uniqueSources.slice(0, 12),
    locale,
    hasApprovedEvidence,
    hasConflicts,
  };
}
