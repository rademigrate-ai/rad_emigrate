# Admin editorial review — recovered research snapshot citation (no publication)

Parent: RAD ONE MASTER TASK #57, E3-03/E3-04. 2026-10-17.

## Confirmed live production issue

- All 16 `research_findings` in review have one matching `content_drafts` row, and 16/16 drafts join to `source_snapshots` and `source_documents`.
- All 16 research-linked drafts have NULL `source_url` and NULL `primary_source_id`, although 16/16 referenced snapshots returned HTTP 2xx and official RAD source authority and 0/16 were removed.
- `AdminReviewActions.loadDraftDetail` previously read only the direct draft URL, so the UI hid that existing evidence.
- `source_documents.source_id` is a nullable FK to `content_sources`, not `research_sources`. For all 16 records it is NULL; no content-source IDs must be fabricated.

## Patch scope

- For an Admin-loaded draft with a research finding and no direct `source_url`, read existing related finding, snapshot and source document **via authenticated Supabase RLS SELECT**.
- Show the original canonical URL only if snapshot has HTTP 2xx, document is not removed, URL scheme is HTTPS, host is a proper non-IP domain and has no URL userinfo.
- Label the URL as snapshot-derived and explicitly warn an editor to verify the original page before publishing.
- If provenance lookup errors, show a distinct warning. Do not claim verification or generate a fallback URL.
- This patch **does not mutate** draft or source metadata. It does not change DB access, publish RPCs, or the Admin-only human publication gate. It does not auto-publish, auto-approve, or claim legal/regulatory authority.

## Verification and release gates

- Pure URL validator: success/failure, missing/removed source, origin ambiguity and private-host negative tests.
- Flutter analyze and targeted tests locally; full Flutter/Web/Android/clean-schema/routing CI on one branch HEAD still required.
- Controlled Admin role browser session must confirm an existing research draft displays the correct verified source URL and warnings; ordinary users must remain blocked by RLS.
- A source URL only identifies the cited captured page — it **does not** prove current visa eligibility, fees, dates, or correct content. Human review must compare the original RAD and official government/institutional sources.
- Real approval/publication and durable draft `source_url` population remain separate OPEN gates.

**Production:** No data/SQL/Auth/Edge/Render changes were performed.
