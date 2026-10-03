# Project 12 — Document Intelligence

Project 12 adds a private, versioned document-processing pipeline around the existing user-owned documents and Storage objects.

Each run creates a job, extraction, structured fields with per-field confidence, and an explicit human-review state. Owners can accept, correct, or reject extracted fields; admins can assist through the same RLS boundary. Foreign-key cascades remove jobs, extracted text, fields, and reviews when the source document or user is deleted.

The `document-intelligence` Edge Function authenticates the caller, verifies document ownership, enforces file-size and timeout limits, downloads through the service boundary, and records only safe error codes. OCR/provider credentials are Vault-backed and service-only. With no provider selected, it returns `document_intelligence_unavailable` and does not fabricate extracted data.

Validation covers rollback migration execution, clean-schema/Auth/RLS/Storage CI, deployment, grants, and Supabase advisors.

## Production verification

- Merged SHA: `0f6365095eb35a584a9d82f34333ae50f1e80134`; CI run 56 passed all schema, security, Flutter, web and Android gates.
- Live migration applied and `document-intelligence` version 1 deployed with JWT verification.
- Runtime credential access is denied to anon/authenticated and granted only to service role.
- Enabled processors: 0. This is the intended honest state until an owner selects an OCR provider and budget.
