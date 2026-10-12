# Live SECURITY DEFINER review — read-only, 2026-10-12

Project `inshddthftkhcdosoqcn` (PostgreSQL 17.11). Evidence came from the
live security advisor and read-only `pg_proc`, `pg_namespace`, `proacl`,
`proconfig`, `pg_get_functiondef`, and `has_function_privilege` queries. No
production RPC was invoked and no live grant, function, setting, or row was
changed. Advisor reference:
https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable

All 14 flagged `public` functions are owned by `postgres`, executable by
`authenticated`, and not executable by `anon` or `PUBLIC`. Twelve have an
empty search path; the two AI access/quota functions have `search_path=public`.
`private.has_role(text[])` checks the signed-in `auth.uid()` against
`public.profiles.role`; it does not trust user-editable metadata. Because a
definer function bypasses table RLS, its body guard is decisive.

| Function | Body guard / scope | Finding |
|---|---|---|
| `configure_ai_provider` | `super_admin`; safe HTTPS URL validation; empty path | Intended privileged RPC; guard present |
| `get_ai_access_decision` | **No caller/target ownership check**; reads target role, entitlement and quota; `search_path=public` | **Confirmed production disclosure/authorization defect** for any authenticated caller supplying another UUID |
| `get_ai_daily_quota_status` | **No caller/target ownership check**; caller chooses `p_role`; `search_path=public` | **Confirmed production cross-user quota disclosure and role-parameter defect** |
| `promote_knowledge_from_evidence` | service-role JWT or Admin/Super Admin role; validation; empty path | Guard present; service path intentionally privileged |
| `publish_content_draft` | Admin/Super Admin, but rejects only `rejected` drafts and permits `draft`/`review` states | **Confirmed workflow defect**: human Admin can publish before approval; not an ordinary-user bypass |
| `register_knowledge_conflict` | service-role JWT or Admin/Super Admin role; empty path | Guard present |
| `retrieve_knowledge` | Read-only `STABLE` query bounded to approved knowledge and approved/conflicting claims, max 20 results | Intended authenticated retrieval; no ownership domain; retain grant unless product contract changes |
| `set_ai_model_configuration` | Admin/Super Admin; bounded parameters; empty path | Guard present |
| `set_content_draft_status` | Admin/Super Admin; allowed states; cannot modify published draft | Guard present |
| `set_research_finding_status` | Admin/Super Admin; allowed states | Guard present |
| `set_research_source_configuration` | Admin/Super Admin; `rad_official` requires Super Admin | Guard present |
| `set_user_role` | Super Admin; enumerated role; audit log | Guard present; role-escalation trigger remains a separate defense |
| `update_content_draft` | Admin/Super Admin; validated content; no published mutation | Guard present |
| `upsert_research_source` | Admin/Super Admin; safe HTTPS URL; first-party/official requires Super Admin | Guard present |

Normalized live/local definitions are identical for 11 of these 14. The
three differences are precisely the two AI ownership RPCs and Feed publication
RPC. The repository's already-tested
`20261010010000_stage1_p0_security_completion.sql` adds owner checks, derives
the user's role from `profiles`, restricts guest decisions to service role,
uses an empty search path, and requires an approved draft before publication.
**Do not edit or apply that migration without the separate production release
authorization.** Revoking all authenticated access from the other 11 would
break intended Admin or retrieval workflows without addressing the actual
defects.

## Exact live signatures and grants

The table below uses `pg_get_function_identity_arguments`, not display
defaults. For **each** listed signature, the live `proacl` has
`postgres=X/postgres`, `authenticated=X/postgres`, and
`service_role=X/postgres`; `has_function_privilege` returned
`authenticated=true` and `anon=false`. All are owned by `postgres` and
marked SECURITY DEFINER. Search paths are shown separately.

| Live function identity | Search path |
|---|---|
+| `public.configure_ai_provider(p_slug text, p_display_name text, p_adapter text, p_base_url text, p_api_key text, p_enabled boolean, p_priority integer)` | empty |
| `public.get_ai_access_decision(p_user_id uuid, p_guest_key_hash text)` | `public` |
| `public.get_ai_daily_quota_status(p_user_id uuid, p_role text)` | `public` |
| `public.promote_knowledge_from_evidence(p_slug text, p_language_code text, p_title text, p_summary text, p_claim_text text, p_snapshot_id uuid, p_excerpt text, p_topic text, p_jurisdiction text, p_destination_code text, p_program_slug text, p_confidence text, p_approve boolean)` | empty |
| `public.publish_content_draft(p_draft_id uuid, p_category text, p_slug text)` | empty |
| `public.register_knowledge_conflict(p_jurisdiction text, p_statement_a text, p_statement_b text, p_citation_a_id uuid, p_citation_b_id uuid, p_proposed_interpretation text)` | empty |
| `public.retrieve_knowledge(p_query text, p_locale text, p_destination_code text, p_program_slug text, p_limit integer)` | empty |
| `public.set_ai_model_configuration(p_model_id uuid, p_enabled boolean, p_runtime_scope text, p_priority integer, p_max_output_tokens integer)` | empty |
| `public.set_content_draft_status(p_draft_id uuid, p_status text)` | empty |
| `public.set_research_finding_status(p_finding_id uuid, p_status text)` | empty |
| `public.set_research_source_configuration(p_source_id uuid, p_display_name text, p_enabled boolean, p_runtime_scope text, p_trust_class text, p_country_code text, p_topic text)` | empty |
| `public.set_user_role(p_user_id uuid, p_role text)` | empty |
| `public.update_content_draft(p_draft_id uuid, p_title text, p_body text, p_language_code text, p_category text)` | empty |
| `public.upsert_research_source(p_source_id uuid, p_display_name text, p_base_url text, p_source_type text, p_trust_class text, p_runtime_scope text, p_enabled boolean, p_country_code text, p_topic text)` | empty |

The two AI functions are callable by authenticated users but, in the live
body, do not require `auth.uid() = p_user_id` (nor a trusted service/Admin
exception). Their `p_user_id` is an input, not a JWT-derived identity.
This is a confirmed body-level authorization defect; no production exploit
probe was executed. The local P0 migration is the minimal existing
remediation, pending the controlled deployment gate.

The local regression `scripts/verify_staging_definer_guards.py` executes 13
protected RPCs as an ordinary authenticated principal inside read-only
transactions. All 13 returned their `forbidden` guard before any write. The
knowledge retrieval RPC is excluded from denial tests because authenticated
retrieval is intentional; its approved-content predicate was inspected.
See `staging_definer_guard_regression.log`. This is local regression, **not a
claim that live unauthorized calls were executed**.

Other live advisor warnings:

- Leaked-password protection is disabled. Auth owner should enable and verify
  it in project settings after assessing signup/recovery UX; no setting was
  changed. Reference:
  https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- `pg_net` is installed in `public`. A DBA should assess extension dependencies
  and a separately rehearsed schema move; do not move it opportunistically.
  Reference:
  https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public

Security disposition: **FAIL production authorization for the two AI RPCs and
pre-approval Feed publication; PASS local remediations; UNVERIFIED production
post-deployment state.** Production remains NO-GO.
