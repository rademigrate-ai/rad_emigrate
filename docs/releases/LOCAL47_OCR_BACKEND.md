# Local OCR backend verification

2026-10-18. Codex-only backend change; no remote pushes or production operations.

The OCR entrypoint delegates to an importable request handler with injected fetch for deterministic testing. Existing successful response fields and `review_required` semantics are retained. The no-configured-provider path remains an honest 503.

The handler validates authentication, UUID input, explicit document ownership and owner-prefixed Storage paths before creating a processing job. Encoded/ambiguous traversal and control characters are rejected. Storage URLs encode each path segment. Storage/provider redirects are rejected without following credentials to another origin. PDF/JPEG/PNG MIME types and magic prefixes must match; these prefixes do not constitute malware scanning or full format validation.

Request, file and provider response streams have byte limits. The file limit is the smaller of provider configuration and the existing 10 MiB private bucket limit. Endpoint syntax excludes IP literals, local hostnames and embedded credentials. Network egress/DNS policy is still needed for rebinding resistance before a real provider is authorized. Extraction fields remain unreviewed and jobs require human review. Arbitrary provider bounding-box objects are not persisted until a bounded coordinate schema is agreed.

Failures use fixed codes and best-effort job termination; raw upstream exceptions/responses, credentials and file contents are excluded from client failure output and job error metadata. A downstream persistence failure does not automatically retry the provider or claim success. Cross-request idempotency and transactional extraction/field persistence remain separate follow-up concerns.

Verified locally:

- Deno 2.5.4: full Edge suite **61 PASS, 0 FAIL**, including **18 OCR cases**. No network permission was granted; all documents/providers are synthetic fixtures.
- Existing Flutter backend/CORS acceptance suite: **9 PASS, 0 FAIL**. Its source-path lookup now follows the extracted handler.
- Deno formatting, Dart formatting and diff whitespace verification pass.

This is local engineering evidence for E8-03, not real-provider performance, privacy/legal consent, deployed E2E or final acceptance. Accepted count remains 3/47.
