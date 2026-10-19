# Currency Converter — Approved Provider Contract

**Status:** Implementation contract (Phase 7)  
**Approved providers only:**

1. **Frankfurter** — primary  
   - Public ECB reference rates  
   - Base URL pattern: `https://api.frankfurter.app`  
2. **Fawazahmed0 Exchange API** — fallback  
   - Public GitHub-hosted rate JSON  

## Explicit non-approvals

- Bonbast and any Iranian open-market / free-market rate provider are **not** approved.
- Reference rates from Frankfurter/ECB must **never** be labeled as Iranian free-market rates.
- IRR vs toman must be distinguished in UI and API (explicit unit field).

## Required behaviors

- Validated provider adapters with timeout and schema checks.
- Rate cache + historical observations.
- Conversion with documented precision rules.
- Provider name and rate-basis labeling on every response.
- Freshness timestamp; offline/cache fallback with explicit stale flag.
- Favorites and currency alerts with deduplication.

## Security

- No user-supplied URL for rate fetch (SSRF prevention).
- Only allowlisted provider hosts.

## Out of scope for this scaffold commit

Full Dart service implementation may follow in a subsequent commit on this branch once baseline tests are green.