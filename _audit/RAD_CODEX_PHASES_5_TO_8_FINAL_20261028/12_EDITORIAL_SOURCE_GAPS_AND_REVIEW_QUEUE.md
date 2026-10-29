# RAD EMIGRATE — EDITORIAL SOURCE GAPS & HUMAN REVIEW QUEUE
**Date:** 2026-10-28  
**Scope:** Reconciled Inventory of Source Gaps, Unavailable Snapshots, and Editorial Review Candidates  

---

## 1. RECONCILIATION COUNTS

Based on the verified delivery package (`final-manifest.json`):
- **Total Ingested Sources**: 2,055
- **Verified Full-Body Captures**: 1,385
- **Non-Editorial / Stateful Exclusions (Preserved with Evidence)**: 406
- **Raw Captures without Complete Article Container**: 214
- **Unavailable / Unfetched Sources**: 50
- **Human Review Queue Items**: 434 (`complete-human-review-queue.jsonl.gz`)

---

## 2. EDITORIAL POLICIES ENFORCED

1. **No Auto-Publishing of Ambiguous Sources**:
   - Items with missing body segments or ambiguous country mappings remain in the review queue with `editorial_approval: false`.
2. **Preserved Listing Excerpts**:
   - Category listing pages and news teasers are preserved in `listing-excerpts.jsonl.gz` for reference but excluded from standalone article creation to prevent duplicate or shallow content.
3. **Stand-Alone Mohajer Articles**:
   - Standalone RAD Mohajer articles stay independent under the "دیگر عناوین" section, rather than being forcefully merged into canonical visa category pages.
