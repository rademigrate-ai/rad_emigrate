# Product Completion DB Gap Manifest

This manifest tracks product capabilities that cannot be implemented safely with the current canonical schema. It is intentionally documentation-only while PR #20 (`fix/canonical-supabase-migration-lineage`) remains unresolved. No migration or production mutation is authorized by this document.

## AI provider and model scope

**Required capability:** Persist and enforce `USER`, `ADMIN`, or `BOTH` applicability independently for providers and models.

**Existing primitive to extend:** `public.ai_providers`, `public.ai_models`, `public.get_ai_runtime_chain`, existing provider-health/fallback orchestration and role checks.

**Minimal additive change after lineage reconciliation:** Add constrained scope metadata to provider/model configuration and make `get_ai_runtime_chain` filter by caller/runtime scope. Existing rows need an explicit safe default chosen from current runtime behavior rather than inferred in the client.

**Security requirements:** Scope enforcement must be server-side; User AI must never obtain Admin-only providers/models; disabled providers/models and finite fallback/cooldown behavior must remain enforced; no credential data may enter runtime-chain responses.

**Tests required:** USER/ADMIN/BOTH selection matrix, disabled provider/model exclusion, priority ordering, finite fallback, role isolation, RLS/RPC authorization and clean-schema reconstruction.

## Provider timeout/retry policy

**Required capability:** Admin-configurable timeout/retry settings where supported by the runtime.

**Existing primitive to extend:** `public.ai_providers`, provider adapters, health/cooldown orchestration.

**Minimal additive change after lineage reconciliation:** Add bounded timeout/retry configuration (or a server-owned policy table if runtime architecture requires it) and consume it only in server-side orchestration.

**Security requirements:** Enforce hard server-side maximums; prevent unbounded retries and request amplification; never accept client policy that bypasses cooldown/health rules.

**Tests required:** bounds validation, timeout behavior, retry cap, cooldown interaction and sanitized failure telemetry.

## Safe provider test

**Required capability:** Test a configured provider from Admin without exposing its stored credential or raw sensitive provider response.

**Existing primitive to extend:** Vault-backed provider credentials, `ai_providers`, `ai_provider_health`, provider adapters/Edge runtime and Super-Admin authorization.

**Minimal additive change after lineage reconciliation:** Add a privileged server-side RPC/Edge operation that resolves the Vault secret internally, performs a bounded test request and returns only a sanitized result/health summary.

**Security requirements:** Super-Admin authorization, Vault secret never returned to SQL/client/logs, SSRF allowlisting/HTTPS validation, bounded timeout/body size, sanitized errors and audit logging.

**Tests required:** permission denial, secret non-disclosure, SSRF rejection, timeout/error sanitization, health update and audit event.

## Provider model discovery and sync

**Required capability:** Discover provider models and let Admin sync selected models, with newly discovered models disabled by default.

**Existing primitive to extend:** `ai_providers`, `ai_models`, Vault credentials and provider adapters.

**Minimal additive change after lineage reconciliation:** Add a privileged server-side discovery operation plus an additive sync operation that upserts model identifiers/metadata without enabling newly discovered models automatically.

**Security requirements:** Same Vault/SSRF/authorization boundaries as provider test; sanitize provider responses; bound response size/count; never trust model identifiers as executable input.

**Tests required:** supported/unsupported adapter discovery, disabled-by-default sync, duplicate/upsert behavior, secret non-disclosure, SSRF rejection and authorization.

## Model priority

**Required capability:** Persist deterministic model priority independently from provider priority.

**Existing primitive to extend:** `public.ai_models` and `get_ai_runtime_chain`.

**Minimal additive change after lineage reconciliation:** Add bounded model priority and incorporate it into deterministic runtime-chain ordering.

**Security requirements:** Server-side ordering only; disabled/scope-ineligible models must remain excluded regardless of priority.

**Tests required:** stable ordering, ties, disabled/scope filtering and fallback behavior.

## Source applicability and editorial metadata

**Required capability:** Persist source applicability (`USER`, `ADMIN`, `BOTH`) and richer Admin source metadata only where the product requires it and existing columns do not already represent it.

**Existing primitive to extend:** `content_sources`, `research_sources`, research allowlist/fetch pipeline and current source RLS.

**Minimal additive change after lineage reconciliation:** Prefer extending existing source records with constrained applicability/editorial metadata rather than introducing duplicate source tables. Add privileged mutation RPCs only for fields that cannot safely be managed through current RLS.

**Security requirements:** Project-primary RAD sources must not be silently demoted by normal Admin edits; URL mutation must preserve SSRF/allowlist protections; source writes require Admin authorization and auditability.

**Tests required:** role/scope visibility, official-source invariants, URL validation/SSRF, mutation authorization, audit events and clean-schema reconstruction.

## Review-state transition API

**Required capability:** A single explicit server-authorized path for Research → review candidate → edited draft → approval → publish, if current table policies do not safely expose every required transition.

**Existing primitive to extend:** `research_findings`, `content_drafts`, `feed_items`, existing review/publish functions and Admin audit logs.

**Minimal additive change after lineage reconciliation:** Add only the missing privileged transition RPC(s); do not create a second publishing architecture. Publishing must require an explicit human Admin action and approved state.

**Security requirements:** No research worker or User AI publish privilege; server-side transition validation; Admin/Super-Admin authorization; immutable/auditable actor and timestamps; sanitized errors.

**Tests required:** forbidden auto-publish, invalid transition rejection, permission denial, edit/approve/publish happy path, audit trail and RLS isolation.
