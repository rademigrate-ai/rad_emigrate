# Document retention and purge — decision and remaining owner inputs

**Owner decision (2026-11-05):** use **hard deletion of the Storage object and the
documents row with a separate immutable audit receipt**, not a retained document-row
tombstone. A transient `pending_deletion` state is permitted only while Storage cleanup
is in progress. This decision supersedes the pre-decision soft-delete recommendation
in section 2 below.

**Engineering status (current continuation):** the two-phase migration, real Edge
worker, owner status UI and bounded dispatcher pass disposable acceptance on fresh
Stack J. Authenticated reads and new signed URLs are denied at request time;
an already issued signed URL remained readable during pending deletion (HTTP 200),
then failed after physical removal. Finalization deletes the row, scrubs the queue
path to `[erased]` and retains a minimal immutable receipt. Preservation holds
block requests/cascades and fail if requested after erasure was accepted. The
retention report is configurable but cannot enqueue or delete anything; its
destructive flag is always refused. The orphan tool remains report-only by default.
See `DOCUMENT_WORKER_OPERATIONS.md` and the final acceptance evidence for limits.
None of these results establishes Production rollout or employer acceptance.

**Still undecided:** lawful retention period, terminal application statuses,
legal preservation precedence, signed-URL expiry/replay acceptance, backup erasure obligations,
and authorization to enable any scheduled automatic deletion. No retention
scheduler or period has been approved or activated.

The original options below were prepared 2026-11-05 against commit `4d7fc00`;
they remain as historical rationale, **not instructions to implement the
superseded soft-delete recommendation**.

---

## 0. Read this first: a defect that is independent of the retention policy

While scoping this I tested the existing delete path on a real stack. **Deleting a document row
leaves its file in Storage, fully readable.**

```
upload object           -> 200
create documents row    -> 201
DELETE the row          -> 204
GET the storage object  -> 200   <- still there
```

The cause: `public.documents` has **no triggers**, and the row and the object are governed by
two separate policies (`documents delete own` on the table, `documents storage delete own` on
`storage.objects`). Nothing links them, so a client that deletes the row and not the object —
or dies between the two calls — orphans a sensitive file indefinitely.

This matters more than the retention window, and it is already live behaviour today:

- A user who believes they deleted an immigration document still has it stored.
- Orphans are invisible to the application: no row references them, so no feature will ever
  surface or clean them up.
- Whatever retention policy is chosen, it must be built on a delete that actually deletes.

**Recommendation: fix this first, as its own change, regardless of what is decided below.**
A `BEFORE DELETE` trigger on `public.documents` cannot reliably delete a Storage object (that
is an HTTP/service concern, not SQL), so the realistic options are (a) a SECURITY DEFINER RPC
that deletes the object then the row, with the direct table DELETE grant revoked, or (b) an
Edge Function that owns the two-step deletion. Option (a) keeps the authorization story in one
place and is the one I would pick. It also needs a reconciliation job for orphans already
created, which on this clean install is zero but on the managed project is unknown.

---

## 1. Retention window — what starts the clock?

| Option | Implication |
| --- | --- |
| **Time since `created_at`** | Simplest; needs no new column. But it deletes documents belonging to applications still in progress, which is wrong. |
| **Time since the parent application reached a terminal state** (recommended) | Matches the actual purpose — the document was needed for a case, the case is closed. Requires knowing what "terminal" means (see below) and tolerating `application_id IS NULL`. |
| **Explicit per-document expiry column** | Most flexible, most operational burden; someone must set it correctly every time, and an unset value is an open question. |

**Blocker to resolve first:** `public.applications.status` and `public.documents.status` have
**no CHECK constraint** — both are free text. Live data currently shows only `submitted` and
`missing`. There is therefore no defined set of terminal states to anchor a retention clock to.
Deciding the retention window requires first deciding, and constraining, the status vocabulary.

**Recommendation:** terminal-state-based, with the status vocabulary pinned by a CHECK
constraint in the same change. A document with `application_id IS NULL` falls back to
`created_at`.

---

## 2. Hard delete vs soft delete

| Option | Trade-off |
| --- | --- |
| **Hard delete** of object and row (recommended for the file) | What data minimisation actually requires. Irreversible, and this project has no restore path, so a wrong purge is permanent. |
| **Soft delete** — tombstone the row, hard-delete the file | Keeps an auditable record that a document existed and was purged, while the sensitive content is genuinely gone. Slightly more schema. |
| Soft delete of both | Does not satisfy data minimisation at all; the file still exists. Not recommended. |

**Recommendation: hard-delete the Storage object, soft-delete the row** (status plus a
`purged_at`, with `file_path` nulled). That removes the sensitive payload while leaving evidence
the purge happened, which is what an audit will ask for. Note this is deliberately *not* the
same answer for the file and the row.

**But a soft delete has a consequence I should flag against my own recommendation.** Two tables
hold `ON DELETE CASCADE` foreign keys to `public.documents`:

| Child table | On row delete |
| --- | --- |
| `public.document_processing_jobs` | CASCADE |
| `public.document_extractions` | CASCADE |

`document_extractions` plausibly holds **OCR-extracted text from the document** — that is, the
same sensitive content in a different column. If the parent row is tombstoned instead of
deleted, the cascade never fires and that extracted text survives the purge. So soft-deleting
the parent is only defensible if the purge **explicitly deletes the extraction and job rows
itself**. Please treat that as part of the scope, not an implementation detail: "purge the
document" has to mean the file, the extractions, and the jobs, or it does not mean anything.

If that feels like too much surface to get right, the simpler and safer answer is a **hard
delete of the row** (letting the cascade do its job) with a separate immutable purge-receipt
row recorded in an audit table that has no FK to the document. That keeps the audit trail
without leaving sensitive derivatives behind. I would switch to this if you want fewer moving
parts.

---

## 3. Scheduled vs owner-initiated

`pg_cron` is installed and available, so either is possible.

| Option | Trade-off |
| --- | --- |
| **Manually invoked, audited purge** (recommended first) | A human decides when destruction happens; easy to observe before trusting it. Relies on someone remembering, so it is not a compliance guarantee on its own. |
| **Scheduled via `pg_cron`** | A real policy that runs without anyone remembering. But an automatic recurring job that destroys user data is a significant thing to switch on, and a logic bug deletes quietly and irreversibly. |
| Dry-run mode plus scheduling | Worth having either way: a function that reports what *would* be purged. |

**Recommendation:** build the purge with a dry-run mode, ship it manually invoked, and only
schedule it after its dry-run output has been reviewed against real data. Do not enable
`pg_cron` for it in the same change that introduces it.

---

## 4. Who may trigger a purge

| Caller | Assessment |
| --- | --- |
| `service_role` (recommended for the retention sweep) | Matches every other privileged RPC in this codebase. Not reachable by a client. |
| `super_admin` | Reasonable for a manual, audited "purge this now" action. |
| The owning user, for their own documents | A *different* requirement — right-to-erasure, not retention. Partly exists already (`documents delete own`), but it is the path proven broken in §0. |

**Recommendation:** `service_role` for the sweep, `super_admin` for a manual single-document
purge, and treat user-initiated erasure as a separate piece of work — it has different rules
(identity verification, response deadlines) and should not be conflated with retention.

---

## 5. Exemptions — what must survive a purge

**Recommendation: exempt a document whose parent application is not in a terminal state, and
make the exemption list explicit and testable rather than implicit.**

Worth stating plainly: the existing "immutable holds" in this codebase are **editorial/content
holds** and do not apply to user documents. The only hold table is
`private.rad_source_publication_holds`, which governs source publication. There is no hold
mechanism covering `public.documents`. So if a legal-hold concept is wanted for documents — for
example, a document under dispute must not be purged — **it does not exist and would need
building.** Please say whether that is in scope.

---

## Where legal input is needed, not engineering judgement

I am not in a position to assert a specific retention period, and would be inventing it if I
did. These need someone who knows the applicable obligations:

- The lawful retention period for immigration case documents in the jurisdictions RAD operates
  in — which may *require* keeping documents for a minimum term, not just permit deleting them.
- Whether a right-to-erasure request must override a minimum retention term, and which wins.
- Whether purge evidence itself must be retained, and for how long.

Until those are answered, I would implement the **mechanism** (a correct, audited, dry-runnable
purge with the §0 orphan bug fixed) and leave the **period** configurable rather than hardcoding
a number that looks authoritative but was guessed.

---

## Suggested order of work, once scope is agreed

1. Fix the orphaned-object defect in §0 — it is live today and independent of all other choices.
2. Pin the application/document status vocabulary with a CHECK constraint.
3. Add the retention schema (`purged_at`, tombstone status) and a dry-run reporting function.
4. Add the purge RPC with exemptions, audit logging, the explicit minimal private-table grant
   self-hosting requires, and — per §2 — explicit handling of `document_extractions` and
   `document_processing_jobs` so no sensitive derivative outlives the purge.
5. SQL regression test plus a real-stack test proving the object, the row, the extractions and
   the jobs are all gone, and that an exempt document survives untouched.
6. Only then consider scheduling.
7. Update ledger item 24 — and only move it off BLOCKED if every listed requirement is
   genuinely satisfied.
