# F-02 — Production hash-mismatch investigation (read-only, 2026-10-12)

Target: document `https://radmohajer.ir/fa/` (id `ee584003-…`) has
`last_content_hash = 643a3c62ef94bc0f5303a69808c4c847d3f87ab73689bb56fc0f506f9c8f8ec9`
which matches **no snapshot row** in `source_snapshots` (0 rows queried by
that exact hash, all documents).

## Evidence gathered (GET-only)

| # | Observation |
|---|---|
| 1 | The document has exactly **1 snapshot** (hash `cace1877…`, fetched 2026-10-07T07:55Z, http 200, metadata `{final_url, source_type: rad_first_party, trust_class: rad_off…}`). |
| 2 | `last_seen_at = 2026-10-11T03:27:06Z` — a **document-only update** on Oct 11 (the sibling `https://digivisa.ir/` doc shows `03:27:05Z` the same run; its `last_content_hash` **does** match its snapshot). No other doc was touched at that time. |
| 3 | Hash `643a3c62…` exists on **no** snapshot anywhere → the value was written to `last_content_hash` without a surviving (or ever-created) snapshot row. |
| 4 | The Stage 3 dataset body for that URL hashes to `dfaeb610…` ≠ `643a…` (different capture/extraction) — no correspondence to current local evidence. |
| 5 | **Algorithm conformance across all 5 seed snapshots:** |

| document | stored hash | == sha256(normalized_text)? |
|---|---|---|
| `https://digivisa.ir/` | `a99199f4…` | **YES** (byte-exact) |
| `https://radmohajer.ir/fa/` | `cace1877…` | **YES** (byte-exact) |
| `https://radmohajer.ir/fa/contacts` | `1720f460…` | NO — none of sha256(norm / norm+nl / strip+nl / crlf) match |
| `https://radmohajer.ir/en/contact-us` | `009442bc…` | NO (same candidates) |
| `https://radmohajer.ir/en/about-us` | `549c84fa…` | NO (same candidates) |

## Conclusions (bounded, no algorithm invented)

1. The historical hashing input is **not uniformly reproducible**: 2 of 5
   seed snapshots are exactly `sha256(normalized_text)`; 3 of 5 are
   **undetermined** (stored text does not hash to the stored value under any
   tested variant — the value may have been computed over input no longer
   present, or the text edited after hashing).
2. `643a3c62…` is an **orphaned `last_content_hash`**: a document-only write
   during the Oct 11 03:27Z run whose snapshot never survived (or never
   existed). Root cause outside current evidence; **not repaired by
   assumption**.
3. **Preservation:** the value is retained verbatim in
   `LIVE_STATE_SNAPSHOT.json`, in `sql/91_rollback.sql` (restore list), and
   in this report. Seed snapshot rows are never modified by the package.

## Effect of the authorized ingestion and its rollback

- Forward: the batch UPDATE sets `last_content_hash` to the new snapshot's
  `sha256(normalized_text)` (the package's documented definition) only when
  materially different — so the anomaly is **healed with provenance**, not
  silently: the pre-value remains retrievable from this report and the
  rollback script.
- Rollback: explicitly restores `643a3c62…` for that document (proven in
  rehearsal: `root_hash_restored=1` checks the digivisa value; the restore
  list covers all 5 prior values including this one).
- No production value was or will be rewritten outside an authorized run of
  the package, and nothing here constitutes a migration or history repair.
