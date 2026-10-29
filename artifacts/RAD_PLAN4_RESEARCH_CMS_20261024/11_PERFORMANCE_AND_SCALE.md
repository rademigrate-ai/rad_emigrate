# 11 — PERFORMANCE AND SCALE

## 1. Web Compilation & Asset Footprint

Plan 4 introduces zero external third-party dependencies, leveraging pure Dart primitives and existing Flutter ecosystem libraries.

- **Production Web Build:** `flutter build web --release` compiled cleanly in **167.5 seconds**.
- **Icon Tree-Shaking:**
  - `MaterialIcons-Regular.otf`: Reduced from 1,645,184 bytes to 30,320 bytes (**98.2% reduction**).
  - `CupertinoIcons.ttf`: Reduced from 257,628 bytes to 1,472 bytes (**99.4% reduction**).
- **Client Contract Footprint:**
  `rad_contract_schemas.dart` compiles JSON schemas into a single compact, pre-parsed Dart map literal, incurring zero network overhead and sub-millisecond parsing on client startup.

---

## 2. Network Latency & Paging Budgets

1. **Paginated Cursor Traversal:**
   Both `listCmsArticles` and `listArticleRevisions` implement strict cursor paging with a hard budget of `maxPagesPerList = 200`. The client tracks visited cursor tokens in a set (`final visited = <String?>{}`) to fail closed immediately on cyclic or infinite pagination attacks.
2. **Deterministic RPC Timeout:**
   All administrative CMS RPC calls enforce a default 15-second timeout (`Duration(seconds: 15)`). Slow network connections or hanging PostgreSQL locks abort deterministically, throwing `CmsException('network')` rather than freezing the UI thread.
3. **Idempotent Network Retries:**
   All mutating calls (`submit_visa_article_review`, `approve_visa_article_revision`, `publish_visa_article_revision`, `rollback_visa_article`, `enqueue_research_refresh`) take a client-generated UUID `request_key`. Unstable mobile connections can safely retry without triggering duplicate revisions or side-effects.
