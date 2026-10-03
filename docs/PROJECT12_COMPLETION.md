# Project 12 — Document Intelligence

Project 12 adds a private, versioned document-processing pipeline around the existing user-owned documents and Storage objects.

Each run creates a job, extraction, structured fields with per-field confidence, and an explicit human-review state. Owners can accept, correct, or reject extracted fields; admins can assist through the same RLS boundary. Foreign-key cascades remove jobs, extracted text, fields, and reviews when the source document or user is deleted.

The `document-intelligence` Edge Function authenticates the caller, verifies document ownership, enforces file-size and timeout limits, downloads through the service boundary, and records only safe error codes. OCR/provider credentials are Vault-backed and service-only. With no provider selected, it returns `document_intelligence_unavailable` and does not fabricate extracted data.

Validation covers rollback migration execution, clean-schema/Auth/RLS/Storage CI, deployment, grants, and Supabase advisors.
