# RAD document hard deletion — engineering receipt and operator boundaries

Date: 2026-11-05. Scope: PR #89; independent self-hosted stack; **no Production rollout approval**.

## Selected contract

The owner selected **hard deletion of the Storage object and `public.documents` row, plus a separate immutable audit receipt**. The `pending_deletion` document state exists only while a worker removes the object; this is not a long-term retention policy. The migration is `supabase/migrations/20261105120000_rad_document_hard_deletion.sql` and must be installed using the normal migration order.

The Flutter Supabase document repository calls `request_document_deletion` rather than deleting Storage or the row itself. The RPC checks owner/admin eligibility, marks a stored document pending and queues a private leased item. Direct client row deletion is disabled. Storage RLS also rejects owner reads/updates/deletes of a pending item and rejects direct client deletion of an object already referenced by a `documents` row, even when its metadata is hidden from that user by RLS. A BEFORE DELETE trigger blocks direct/service-side row deletion **and FK cascades from applications/auth.users** for documents with stored objects until the leased worker's finalization has confirmed Storage removal. Operators must complete document cleanup before deleting a parent application/account. A missing, never-uploaded document placeholder may be finalized synchronously without inventing an object.

Only the server-side `document-deletion` Edge Function may drive queue claims and physical Storage deletion with a service-role credential. It deletes the object through the Storage API, verifies an actual `404` or the observed self-hosted Storage `400/NoSuchKey` absence response, then calls the finalize RPC. An authorization, network or server error on verification **must not** count as proof of deletion. The finalization deletes associated rows via existing FK cascade and writes an immutable receipt with a hashed storage reference, without retaining original document contents or paths. A failed deletion remains pending and retryable up to the configured attempt ceiling.

**Worker activation is not automatic.** The function accepts service-role-authenticated `POST /functions/v1/document-deletion` calls and processes one queued request per invocation. A trusted server-side dispatcher must invoke it with bounded cadence/retries, protected credentials, health alerting and queue monitoring. Configure and verify that dispatcher before declaring document deletion operational in a deployed environment; do **not** expose the service role to Flutter or the browser. Do not mistake user-authorized queue processing for an approved scheduled retention purge: no time-based retention sweep is authorized.

## Locally executed disposable acceptance

- SQL candidate and `supabase/tests/rad_document_hard_deletion.sql` passed inside a **rollback-only** transaction on independently installed Stack E (118 prior RAD migrations). This is not a new 119-migration from-zero receipt.
- Stack F received diagnostic copies/patches of the uncommitted candidate in a separately owned test stack; its SQL regression passed. This is not a managed Production migration.
- `scripts/verify_self_host_document_deletion.py` with two synthetic Auth users and private Storage objects passed: unauthorized calls denied; registered Storage object cannot bypass the audited delete; pending objects cease to be readable; worker deletes the physical object and parent row; receipt remains immutable and owner-scoped; never-uploaded placeholder deletes without Storage; synthetic Auth users can be removed.
- The same E2E passed with `RAD_SELF_HOST_TEST_EDGE_FUNCTION=1` against the **deployed Edge Function in Stack F**, not merely a Python replication of the worker.
- The orphan reconciler `scripts/reconcile_self_host_storage_orphans.py` defaults to REPORT_ONLY. Destructive mode requires a separately reviewed exact path per object with `--approved-object`, a minimum age, and re-checks. It must never be scheduled or run on unapproved Production objects.

## Known acceptance limits

1. Previously issued signed Storage URLs may remain usable until physical deletion or expiry. Test expiry/replay on the intended Storage version and avoid promising revocation at the instant the row is hidden.
2. Backup copies, caches and snapshot erasure are separate from removal of the live object. Legal retention durations and hold priority are undecided.
3. Production dispatcher, SMTP/secrets, queue alerting and owner deployment approval remain external or operational gates.
4. A full fresh clean installation **including this new 119th migration**, complete CI on the final commit and Flutter UI verification remain separately required.
5. Orphan cleanup is intentionally approval-per-object and is not equivalent to a general automatic purge guarantee.

## Verification and release policy

Run the full Edge Function Deno suite, SQL regression, isolated real Storage/Auth E2E, Python regression suite, Flutter formatting/analysis/tests, fresh migration-reconstruction and all eight CI jobs on **one final HEAD**. Keep PR #89 Draft/unmerged, do not modify Supabase.com Production or delete any unapproved data or infrastructure.
