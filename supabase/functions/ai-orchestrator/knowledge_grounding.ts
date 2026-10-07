/** Stage 2 Knowledge grounding — retrieve_knowledge RPC with approved-items fallback. */
export type Source = { title: string; url: string; authority: string; retrieved_at?: string; excerpt?: string };

type DbFn = (path: string, init?: RequestInit) => Promise<any>;

export async function loadGrounding(
  db: DbFn,
  scope: "user" | "admin",
  queryHint?: string,
): Promise<{ text: string; sources: Source[] }> {
  const sources: Source[] = [];
  const excerpts: string[] = [];
  let usedRpc = false;
  try {
    const payload = await db("rpc/retrieve_knowledge", {
      method: "POST",
      body: JSON.stringify({
        p_query: (queryHint ?? "").slice(0, 500),
        p_locale: "en",
        p_destination_code: null,
        p_program_slug: null,
        p_limit: 8,
      }),
    });
    const results = Array.isArray(payload?.results) ? payload.results : [];
    if (results.length > 0) {
      usedRpc = true;
      for (const item of results) {
        if (item?.title) excerpts.push(`${item.title}: ${item.summary ?? ""}`);
        for (const claim of item?.claims ?? []) {
          if (claim?.claim_text) excerpts.push(String(claim.claim_text));
          if (claim?.review_status === "conflicting") {
            excerpts.push(`[CONFLICT] ${claim.claim_text}`);
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
              });
            }
          }
        }
        for (const conf of item?.open_conflicts ?? []) {
          excerpts.push(`[OPEN CONFLICT] A: ${conf.statement_a} | B: ${conf.statement_b}`);
        }
      }
    }
  } catch {
    // RPC unavailable — fall through
  }
  if (!usedRpc) {
    const approved = await db(
      "knowledge_items?select=id,title,summary,knowledge_claims(claim_text,knowledge_citations(excerpt,source_snapshots(fetched_at,source_documents(title,canonical_url,source_authority))))&review_status=eq.approved&order=updated_at.desc&limit=6",
    );
    for (const item of approved ?? []) {
      excerpts.push(`${item.title}: ${item.summary}`);
      for (const claim of item.knowledge_claims ?? []) {
        excerpts.push(String(claim.claim_text ?? ""));
        for (const citation of claim.knowledge_citations ?? []) {
          const snapshot = citation.source_snapshots;
          const document = snapshot?.source_documents;
          if (document?.canonical_url) {
            sources.push({
              title: document.title,
              url: document.canonical_url,
              authority: document.source_authority,
              retrieved_at: snapshot.fetched_at,
              excerpt: citation.excerpt,
            });
          }
        }
      }
    }
  }
  if (scope === "admin") {
    const snapshots = await db(
      "source_snapshots?select=fetched_at,normalized_text,source_documents(title,canonical_url,source_authority)&order=fetched_at.desc&limit=6",
    );
    for (const snapshot of snapshots ?? []) {
      const document = snapshot.source_documents;
      if (!document?.canonical_url) continue;
      excerpts.push(String(snapshot.normalized_text ?? "").slice(0, 4000));
      sources.push({
        title: document.title,
        url: document.canonical_url,
        authority: document.source_authority,
        retrieved_at: snapshot.fetched_at,
      });
    }
  }
  return {
    text: excerpts.filter(Boolean).join("\n\n").slice(0, 24000),
    sources: [...new Map(sources.map((source) => [source.url.toLowerCase(), source])).values()].slice(0, 12),
  };
}
