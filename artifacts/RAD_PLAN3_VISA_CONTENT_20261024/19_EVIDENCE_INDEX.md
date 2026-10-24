# Evidence index and reproducibility

* `01` inventory: every current discovered source identity and disposition.
* `02` historical reconciliation: missing 812/10 report evidence, current membership unknown; preserves actual existing source IDs.
* `03` fetch results: HTTP, redirect, error, retrieval and raw HTML hashes.
* `04` body completeness: actual parser assessment; full source text is in data/sources.jsonl.gz.
* `05`/`06`: canonical groups, exact duplicates and unresolved near/conflict relationships.
* `07`/`08`: Country × Pathway and actual hosted structured-data gaps, not inferred legal completion.
* `09`: citation/snapshot/body-reference/date manifest; all legal verification pending.
* `10`: initial draft-only payload index and compressed request records.
* `11`/`12`/`13`: isolated rehearsal/runbook, deterministic quality checks, actual test evidence.
* `14`/`15`/`16`: unchanged runtime contracts and Antigravity/Grok handoffs.
* `17`/`18`: editorial queue and independent content gates.
* `data/discovery.json`: actual robots/sitemap evidence, declared dates and URLs.
* `data/production_*`: timestamped read-only public content metadata from initial delivery, not a current hosted readiness assertion; no private user records or secrets.
* `data/sources.jsonl.gz`: original complete/partial bodies, lists/tables, source IDs, provenance, hashes and dates. Large raw HTML remains in external owned cache, never in Git.
* `data/canonical_articles.jsonl.gz`: complete preferred source bodies with all source identities and version/block hashes. No composite legal text is invented.
* `data/cms_drafts.jsonl.gz`: exact closed-v1 create/save requests; invalid entries retained with blockers, not imported.
* `data/canonical_identity_registry.json`: retained source→canonical identities for subsequent captures.
* `data/taxonomy.json`: versioned inference rules, not administrative approval.

`data/capture.jsonl.gz` retains the compact parsed collection input, without raw HTML or repeated site navigation. Rebuild offline using the exact command in `tools/plan3_content/README.md`, including `--schema-gate`; use a new owned output directory. Copy the identity registry and evidence directory when reproducing the complete sealed delivery. The library validator checks inventory rows, manifests, body/provenance identities, pipeline fingerprints and payload hashes. Discovery is explicit network work via `python -m tools.plan3_content.crawl --help`; offline validation does not refetch sites. Raw-byte hashes, pipeline fingerprints and content hashes distinguish evidence snapshots from present-day site content. Parser re-extraction from original HTML additionally requires the external owned raw cache.

`PLAN3_MANIFEST.json` supplies counts and current gates. `CHECKSUMS.sha256` seals every package file except itself. Verify using `python -m tools.plan3_content.cli checksums --directory artifacts/RAD_PLAN3_VISA_CONTENT_20261024`. Check GitHub required checks on the exact final branch HEAD; another SHA's green run is not substituted. No Production writes, imports, migration repairs, RLS disabling, deployments or automatic publications occur.
