# Document deletion operations

Individually authorized erasure and a timed retention purge are separate operations.
No timed purge, retention duration or legal precedence has been approved or enabled.

`deploy/self-hosted/document-retention-policy.example.json` leaves duration, clock,
terminal statuses and approval reference unset. Inspect it with
`python scripts/document_retention_report.py --policy <policy.json>`. The report
refuses any enabled destruction flag and cannot enqueue or delete documents.
An explicitly configured report currently supports only the document creation
clock, requires named terminal application statuses, excludes preservation holds
and existing deletion requests, and returns counts without object paths. It does
not authenticate an approval reference or establish a lawful policy. A closure
clock needs an approved definition and corresponding schema before implementation.

The server accepts owner/admin requests, restricts access, and leases a persistent
queue entry to `document-deletion`. Only a confirmed Storage absence allows the
worker to finalize the row, remove derivatives, erase the operational path and
append an immutable receipt. A fifth active lease remains valid until expiry.
Network diagnostics are classified into fixed codes; exception URLs are not saved.

Stored references cannot be detached, reassigned or replaced through row updates.
Delete an existing stored document and create a new document to replace it. Both
registration and request authorization enforce the document owner's Storage prefix.
Pending object paths also reject new uploads, including attempts to recreate an
object after physical removal but before finalization. The worker recognizes the
verified Storage `400 NoSuchKey` absence response on DELETE and on its independent
read probe; generic 400, authorization failures and server errors remain failures.
Finalization must return the claimed request ID and an explicit finalized state.
The client shows pending, retrying, staff-attention and completed states separately,
using the path-free, owner-scoped `list_document_deletions` RPC. Active requests
refresh every five seconds while the page is open. Exhausted work is not presented
as completed or silently requeued by a client.

An authenticated admin can call `set_document_preservation_hold(document_id, true)`
before a deletion request is accepted; releasing it requires an explicit `false`.
The change is audited. A hold prevents request-time deletion and SQL/FK cascades,
including placeholders. A hold requested after erasure was accepted is rejected:
the worker might already be removing the object, so preservation cannot be promised.
These controls do not decide lawful retention duration or override priority.

## Disposable dispatcher activation

The dispatcher defaults to a health report and accepts only an owned, loopback
installation validated by `self_host_test_target`. It loads the service key from
the install's private `.env`; never pass that key on a command line or to Flutter.

```powershell
$env:RAD_SELF_HOST_TEST_ROOT = '<owned disposable installation directory>'
python scripts/document_deletion_dispatcher.py
python scripts/document_deletion_dispatcher.py --execute --max-jobs 10 --interval 2
```

One process invokes one worker at a time, at most 100 times, with bounded delay
and backoff. SQL leases protect concurrent independent invocations. Restarting a
dispatcher does not reset queue attempts or bypass an unexpired lease. A network
failure or an unconfirmed worker result never increments the finalized count.

Health output contains aggregate pending/leased/exhausted counts and oldest age,
without document paths or contents. Exit 2 and JSON `alerts` signal exhausted
retries, a stale queue (default 300 seconds, operator-configurable) or unavailable
health/worker execution. Route exit codes and alerts to the operator's monitoring
system; external alert delivery and unattended service activation require the
deployment operator's configuration. This tool does not activate Production.

## Signed previews

The client creates a fresh, owner-authorized 300-second URL only when opening a
preview; cached document models carry no preview token. A request denies new
authenticated object reads and new signed URLs. Previously issued URLs are bearer
capabilities: replay may remain possible until expiry or physical removal.
New client uploads request `max-age=0` to require cache revalidation instead of
the SDK's one-hour default. This does not rewrite older objects' metadata or
erase a previously downloaded response. Verify the actual response headers in
the release browser test and again through the eventual proxy.
The pinned self-hosted Storage route did not emit a Cache-Control header for a
signed GET even when object metadata contained `max-age=0`. The installer now
adds `Cache-Control: private, no-store, max-age=0` on all Storage gateway responses,
preserving the existing route rewrite and authentication filters. Preparation
records the original/installed template hashes and refuses an unknown upstream
route. The operator Caddy template keeps the same private no-store policy.
Downloaded files and browser memory cannot be remotely erased. Loopback HTTP
tests do not certify a future CDN or proxy cache; test its headers and purge
behavior before making stronger deployment guarantees.

## Recovery and reconciliation

Use `document_deletion_queue_health` with the server role to inspect aggregate
failure visibility. Do not manually finalize an object whose absence has not
been verified. Five attempts bound automated retries; investigate exhausted
failures and preservation conflicts before a separately reviewed recovery.

`reconcile_self_host_storage_orphans.py` remains report-only by default. Destruction
requires exact, individually approved paths, age checks and fresh database/queue
reference checks. Never schedule a blanket sweep or infer consent from this guide.
