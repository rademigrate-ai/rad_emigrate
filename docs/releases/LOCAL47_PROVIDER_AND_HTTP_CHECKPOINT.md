# Local provider boundary and HTTP checkpoint

2026-10-18; backend working snapshot following `416a26a`. Local only. Accepted count remains **3/47** and release remains **NO-GO**. No production change, real provider request, paid inference, external message or remote Git update occurred.

## Provider boundary

The orchestrator now sends application instructions through each adapter's native system field. Caller roles cannot create a system message; retrieved evidence remains in a separate untrusted user message. This preserves the existing reply, sources and uncertainty fields and adds optional `refused` and `truncated` booleans. Explicit refusals terminate routing and force uncertainty; incomplete output is labelled uncertain. These controls are not proof that arbitrary semantic prompt injection is defeated.

Provider JSON is bounded to 1 MB (catalogue pages: 5 MB), decoded strictly and validated before an answer is accepted. Blank/malformed output fails over with a fixed code. Claude text blocks and Gemini public text parts are combined without exposing thinking blocks; malformed usage counters stay unknown. Known configured credential echoes, control characters and excessive text are suppressed. Pricing/cost and total billable reasoning usage are not invented. A provider-health write failure after completed inference no longer starts another billable attempt. Incoming JSON is limited to 2 MB, and null/non-text messages cannot crash or enter authenticated quota reservation.

AI, Research and OCR use a shared literal URL guard that also rejects mapped/compatible IPv6 and trailing-dot local aliases. Research retains its exact source-host check; OCR retains its stricter endpoint rules. This is syntax validation, not DNS-rebinding protection or an egress firewall. Approved deployment/network controls remain necessary.

Official response/request formats consulted: [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create), [Claude messages](https://platform.claude.com/docs/en/build-with-claude/working-with-messages), [Claude stop reasons](https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons), and [Gemini generateContent](https://ai.google.dev/api/generate-content). No model or vendor selection is implied.

## Local verification

- Deno **2.5.4**: `deno test --allow-env supabase/functions/tests` — **102 PASS / 0 FAIL** after formatting. Network access is denied; upstream calls are synthetic fixtures. Includes 13 provider parser/URL/native serialization tests and seven new orchestration tests.
- Python: `python -m unittest discover -s scripts/tests -v` — **27 PASS**.
- Flutter acceptance: initial run **95 PASS / 1 FAIL**, the already-corrected grounding source assertion from `66c5820`. Reused that authored commit as `416a26a`; focused `stage1_ai_research_completion_test.dart` then **9 PASS**. The final integrated candidate still needs its complete Flutter run.
- New TS files: Deno formatter completed. Existing frontend source was not changed.

## HTTP and database evidence

`scripts/verify_local47_http.py` uses the actual sandbox payment handler and notification worker in a restricted loopback Deno server, then real local PostgREST/PostgreSQL. Its [report](local47_http_verify.json) records **16 signed retries / one event**, forged and stale signatures denied, stale/terminal subscription updates ignored, one notification sandbox receipt and zero on replay, and unchanged canonical entitlements. It does not exercise Supabase's Edge Runtime deployment or any real payment/notification provider. Test users are removed, configuration restored and the test server terminated. Credentials stay in memory.

`scripts/measure_local47_fk_plans.py` checks its dedicated runtime ownership marker and measures three actual FK probes using 10,000 synthetic consultations and 20,001 synthetic claims. With default planner settings all three choose an Index Scan; dropping only those indexes inside the same transaction yields Seq Scans with identical 100-row results. ROLLBACK restores fixtures and indexes; all three restored indexes are checked. See [measured plans](local47_fk_plans.json). Timings are local examples, not production capacity/SLO claims.

Both reports identify the dirty working snapshot honestly. Separately, [clean backend checkpoint evidence](local47_clean_47835e8.json) captures the fresh 56-migration canonical replay, complete database/Auth/RLS/Storage/human-publication checks and parallel-session integrity run on clean immutable `47835e8`. That proves this earlier backend commit only, not the final integrated release or a production restore.

Real credentials, vendor privacy/cost approval, reviewed factual evaluations, production-equivalent release validation and owner acceptance remain open. No acceptance gate is promoted by this checkpoint.
