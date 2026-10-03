# Project 13 — Admin Operations

Project 13 adds an RLS-enforced operations plane for verified `admin` and `super_admin` profiles.

The data layer provides private case notes, assignable tasks, immutable application status history, saved filters, admin visibility into user cases/documents, and audited status/role changes. Only Super Admin may call the role-change RPC; client updates cannot mutate `profiles.role`.

The responsive Flutter route `/admin` checks the live profile role and shows operational counts for applications, documents, research, AI, document processing, tasks, and—only for Super Admin—audit events. Direct route discovery does not grant data access because every query is independently protected by RLS.

Provider credentials remain Vault-only. Existing provider health and job tables are visible through the admin boundary without exposing prompts, document contents, tokens, or secret values.
