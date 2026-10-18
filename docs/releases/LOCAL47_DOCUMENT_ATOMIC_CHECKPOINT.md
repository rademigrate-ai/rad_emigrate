# Local atomic document-processing checkpoint

2026-10-18. Forward-only proposal `20261018152513_local47_document_atomic_processing.sql`, created with Supabase CLI 2.119.0. This is local engineering evidence, not OCR provider approval, production deployment or owner acceptance. **3/47 VERIFIED_PASS; release NO-GO.**

## Processing and review contract

Service-only `begin_document_processing` locks the owned document briefly, returns one private 120-second lease, and fences simultaneous calls. Other calls receive HTTP **202**, `job_id`, `status=running`, `retry_after_seconds=5`; the lease is never exposed. Five new jobs per document and twenty per user per hour are allowed, including failed attempts; a user advisory lock protects the cross-document counter. Further calls return HTTP **429** and a retry hint. In-flight duplicates do not consume another job. Expired jobs fail explicitly, and a fresh job can claim a replacement lease.

No provider call occurs inside a SQL transaction. Completion atomically inserts the extraction and its fields and marks the job `review_required`. It requires the matching unexpired lease, owner/path and Storage object identity/version/timestamp snapshot. A changed file, including a replacement at the same path, cannot accept stale output. SHA-256 records the bytes processed. Duplicate completion returns the already persisted result and never overwrites subsequent human corrections. Failure and completion races leave a consistent terminal state.

Clients can read owned results and update only review columns. Raw values, confidence, extraction identity and source metadata cannot be rewritten. Human corrections require text, receive database-attributed reviewer/time and append review history. Engine-supplied fields always start unreviewed, and engine bounding boxes are not accepted as trusted metadata. Private leases and hashes are not client-readable. Direct client job insertion is revoked; existing processing request/success fields remain compatible.

Auth account deletion can internally clear a reviewer reference before cascading owned document data. The initial HTTP test caught a trigger rejecting that cleanup. The trigger now permits only an exact internal reviewer-reference nulling with no other column change; authenticated review updates still receive server attribution. Both identified failed-run synthetic accounts were removed through Auth after the fix. This exception does not authorize client raw-field writes.

## Evidence

- Full Deno 2.5.4 suite: **105 PASS / 0 FAIL**. OCR suite: **21** tests, including busy/rate responses, atomic RPC usage, credential echoes and sanitized failure handling. All provider fixtures use synthetic data and no network access.
- [Full disposable database verification](local47_document_verify.json): pinned eight-dimension core schema, all SQL security/AI/Research/CRM/payment/document tests, real two-user Auth/Storage/RLS and human-only Feed publication checks passed on the proposal snapshot.
- [Parallel native SQL sessions](local47_document_concurrency.json): **32 claims / one winner**, **20 completions / one persistence winner**, stale-token fencing after replacement, and **20 failure/completion race requests** with no partial extraction. Only allocated synthetic users/documents were removed afterward.
- [Deno HTTP → Auth/Storage/PostgREST/SQL](local47_document_http.json): real local private PDF upload and user tokens, **12 busy requests / one synthetic OCR call**, one extraction, initially unreviewed fields, cross-owner denial, denied raw-field tampering and one correctly attributed human-review audit. Two synthetic accounts, the Storage object and a temporary synthetic Vault secret were removed; all original processor configuration fields were restored.
- Flutter backend acceptance: **96 PASS**. Python tests: **27 PASS**. New/changed TS files formatted; shell entrypoints syntax-checked. Full final integrated Flutter/build/browser checks remain the integration owner's responsibility.

The HTTP harness runs ordinary Deno with loopback-only network permissions. Its OCR adapter is an explicit in-memory fixture; it is neither a real OCR engine nor a Supabase Edge Runtime deployment. No extraction-accuracy, malware-scanning, provider-consent or real-vendor claim is made. Document/user cascade tests do not establish an approved retention schedule or production backup deletion. Evidence freshness, retention periods, real OCR integration and release approval remain external decisions.

Clean-schema and historical-reconstruction shell runners now also execute the local CRM, payment, document, runtime ACL and Knowledge/AI regressions so final CI cannot silently omit these SQL checks. Windows local replay uses the corresponding native runner. Working-snapshot reports identify dirty source honestly; clean exact-commit replay will be captured separately outside the checkout.

Reproduction commands (installed paths supplied as arguments):

```text
python scripts/verify_local_stack.py verify --supabase <supabase.exe> --psql <psql.exe> --report <report.json>
python scripts/verify_local47_document_concurrency.py --psql <psql.exe> --report <report.json>
python scripts/verify_local47_document_http.py --supabase <supabase.exe> --psql <psql.exe> --deno <deno.exe> --report <report.json>
```

Run the owned local stack with the complete proposal first. Never apply this proposal against production without the independent rollout/backup/review gate.

## Clean immutable checkpoint replay

[Retained clean `cceebae` evidence](local47_clean_cceebae.json) now contains ten successful reports: fresh canonical replay of all 57 files, captured 25-version historical baseline plus 32 forward files, full security/Auth/Storage suites on both, 27 matching catalog groups, document concurrency and HTTP/Storage composition, CRM/outbox/payment concurrency, sandbox HTTP and mailbox recovery. Embedded source metadata records `source_dirty=false`; the operations concurrency report predates that field and is explicitly identified as an invocation within this same clean-checkpoint sequence. It does not prove final integrated acceptance or production restore.

The first parallel CLI stop collided in Docker container pruning. The failed attempt is retained, owned remaining containers were inspected, and a sequential retry succeeded before either fresh replay. No unrelated project was stopped. Future Docker lifecycle changes should run sequentially.
