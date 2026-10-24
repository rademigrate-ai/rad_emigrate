# 12 — EDGE FUNCTION INTEGRATION

## 1. Edge Function Topology & Responsibilities

The RAD Emigrate backend divides autonomous intelligence and source synchronization into dedicated Supabase Edge Functions:

```
┌─────────────────────────┐       ┌───────────────────────────────┐
│ official-source-worker  │       │       ai-orchestrator         │
│  - Egress domain check  │       │  - Grounding & citation check │
│  - HTML/PDF crawl       │       │  - User assistance quotas     │
│  - Compute SHA256 hash  │       │  - Zero CMS publication rights│
└───────────┬─────────────┘       └───────────────┬───────────────┘
            │                                     │
            ▼                                     ▼
┌─────────────────────────┐       ┌───────────────────────────────┐
│   visa-content-ingest   │       │   PostgreSQL / RPC Gateway    │
│  - Parse sections       │──────►│  - Enforce RLS & Contracts    │
│  - Extract claims       │       │  - Draft / Revision Storage   │
│  - Draft proposal row   │       │  - Human-controlled publish   │
└─────────────────────────┘       └───────────────▲───────────────┘
                                                  │
                                       ┌──────────┴──────────┐
                                       │  Flutter Admin CMS  │
                                       │   (Plan 4 Client)   │
                                       └─────────────────────┘
```

---

## 2. Worker Contract Interfaces

### A. `official-source-worker`
- **Trigger:** Dispatched via `enqueue_research_refresh` or cron schedule.
- **Contract:** Defined in `rad_v1.json` as `official_source_worker_request` / `official_source_worker_response`.
- **Output:** Writes to `source_documents` and `source_snapshots` tables with status `fetched`.

### B. `visa-content-ingest`
- **Input:** Snapshot ID and target pathway.
- **Processing:** Extracts statutory terms, compares against current canonical revision, and writes a pending record to `research_proposals`.
- **Boundary Restriction:** The ingest function is granted `INSERT` access on `research_proposals`, but explicitly denied `UPDATE` access to `canonical_pathways` or `feed_items`.

### C. Client RPC Gateway
The client interacts exclusively through PostgreSQL functions (`public.*` schema) secured with PostgreSQL Row Level Security (RLS) and JWT claims, guaranteeing that even if a worker edge function is compromised, it cannot write to published pathways.
