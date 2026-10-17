# RAD Emigrate — PRD-to-code-to-production coverage matrix (2026-10-17)

**Purpose:** One-task traceability crosswalk for 47 acceptance gates in [Master issue #57](https://github.com/rademigrate-ai/rad_emigrate/issues/57). Treat original scope in [RAD_MASTER_COMPLETION_AUDIT.md](RAD_MASTER_COMPLETION_AUDIT.md) and [REMAINING_PRODUCT_ROADMAP.md](REMAINING_PRODUCT_ROADMAP.md) as the source baseline. This report is a **documentary acceptance of E0-03 only**, not a blanket product-release PASS.

**Repository baseline:** `main` SHA `449cd3b6cb0a0b53e852015ad4a3648bd817ad65`; file paths below validated against GitHub's recursive tree. Migration, security and Auth fix branches are **not merged**.

## Interpretation

- **PASS:** the specific audit/checklist gate has a reproducible artifact and acceptance evidence; it does **not** imply the full product function is production-validated.
- **OPEN:** source or test exists but does not satisfy full delivery gate. Paths are evidence pointers, **not a claim of production success**.
- **Production facts:** read-only RAD Supabase inspection showed 22 destinations, 10 visa programs, 44/44 nonempty localized destination summaries, 20/20 nonempty localized program descriptions, 18 visa steps, 8 requirements; **16 research findings and 16 drafts but 0 Feed items**; 7 knowledge items; AI requests 10 successful / 39 failed; document processing disabled, 0 jobs; 3 Auth users. These counts do not attest regulatory accuracy or editorial sign-off.
- **Release blockers:** Supabase live migration ledger has 47 versions vs 46 main migration files (27 exact, 16 same-name different-version, 4 live-only, 3 repo-only); see PR #56 corrected [live-ledger report](https://github.com/rademigrate-ai/rad_emigrate/blob/security/stage1-reconciliation-20261017/docs/releases/LIVE_MIGRATION_RECONCILIATION_20261017.md). PR #59 combined code CI passed 7/7 but not deployed. Auth PR #58 unmerged. Payment, signing, SMTP/SMS and legal approvals cannot be fabricated.

## All 47 gates: implementation/reference traceability

| # | Gate / expected workstream | Existing main-branch source and reference | Verified delivery gate |
|---:|---|---|---|
| 01 | E0-01 Production baseline and inventory | `docs/RAD_MASTER_COMPLETION_AUDIT.md`; `docs/FINAL_RELEASE_MATRIX.md` | PASS — read-only baseline documented |
| 02 | E0-02 Web/mobile/admin route & control audit | `lib/core/routing/app_router.dart`; `docs/CORRECTIVE_FEATURE_ACCEPTANCE_MATRIX.md` | OPEN — evidence and production gate incomplete |
| 03 | E0-03 PRD feature coverage matrix | `docs/RAD_MASTER_COMPLETION_AUDIT.md`; `docs/REMAINING_PRODUCT_ROADMAP.md` | PASS — traceability matrix produced |
| 04 | E0-04 Release A/B scope freeze | `docs/REMAINING_PRODUCT_ROADMAP.md`; `docs/RELEASE_EXTERNAL_DEPENDENCIES.md` | OPEN |
| 05 | E1-01 reconcile PR #48/#56 with main (review/integration PASS; production release NO-GO) | `supabase/reconciliation/security_regression.sql`; `scripts/verify_clean_schema.sh` | PASS — isolated PR integration; release NO-GO |
| 06 | E1-02 migration ledger/content drift reconciliation | `docs/SUPABASE_MIGRATION_LINEAGE_RECONCILIATION.md`; `scripts/verify_migration_reconstruction.sh` | OPEN — evidence and production gate incomplete |
| 07 | E1-03 RLS cross-role/adversarial tests | `scripts/verify_local_auth_isolation.py`; `supabase/reconciliation/security_regression.sql` | OPEN — evidence and production gate incomplete |
| 08 | E1-04 SECURITY DEFINER privilege audit | `docs/FINAL_SECURITY_ACCEPTANCE.md`; `supabase/reconciliation/security_regression.sql` | OPEN — evidence and production gate incomplete |
| 09 | E1-05 Auth/storage/abuse/backup security hardening | `docs/AUTH_ARCHITECTURE.md`; `docs/ANDROID_RELEASE.md` | OPEN — evidence and production gate incomplete |
| 10 | E1-06 FK/query performance remediation | `supabase/migrations/20261005190000_stage3_fk_covering_indexes.sql`; `scripts/verify_clean_schema.sh` | OPEN — evidence and production gate incomplete |
| 11 | E2-01 provider credentials/routing operational health | `lib/features/admin/data/admin_ai_config_repository.dart`; `supabase/functions/ai-orchestrator/handler.ts` | OPEN — evidence and production gate incomplete |
| 12 | E2-02 AI models eligibility & discovery | `lib/features/admin/presentation/pages/admin_ai_config_page.dart`; `docs/AI_ENTITLEMENT_CONTRACT.md` | OPEN — evidence and production gate incomplete |
| 13 | E2-03 atomic quotas and concurrency | `supabase/functions/ai-orchestrator/handler.ts`; `docs/AI_ENTITLEMENT_CONTRACT.md` | OPEN — evidence and production gate incomplete |
| 14 | E2-04 grounded answer + citation evaluation | `docs/USER_AI_GROUNDING_CONTRACT.md`; `docs/USER_AI_CITATION_CONTRACT.md` | OPEN — evidence and production gate incomplete |
| 15 | E2-05 AI observability/security/cost | `docs/FINAL_SECURITY_ACCEPTANCE.md`; `docs/RELEASE_READINESS_MATRIX.md` | OPEN — evidence and production gate incomplete |
| 16 | E3-01 RAD source ingestion and snapshots | `docs/KNOWLEDGE_INGESTION_CONTRACT.md`; `supabase/functions/research-sync/index.ts` | OPEN — evidence and production gate incomplete |
| 17 | E3-02 authoritative government sources & conflicts | `docs/KNOWLEDGE_INGESTION_CONTRACT.md`; `docs/KNOWLEDGE_RETRIEVAL_CONTRACT.md` | OPEN — evidence and production gate incomplete |
| 18 | E3-03 finding→draft→human approval→Feed | `lib/features/feed`; `supabase/functions/research-sync/index.ts` | OPEN — evidence and production gate incomplete |
| 19 | E3-04 review 16 production drafts | `lib/features/admin`; `lib/features/feed` | OPEN — evidence and production gate incomplete |
| 20 | E3-05 bilingual Visa catalog evidence-backed completion | `lib/features/visa`; `docs/CORRECTIVE_FEATURE_ACCEPTANCE_MATRIX.md` | OPEN — evidence and production gate incomplete |
| 21 | E3-06 bilingual search/FAQ/Feed usability | `lib/features/visa`; `lib/features/feed` | OPEN — evidence and production gate incomplete |
| 22 | E4-01 Auth/OTP/recovery/deep-links E2E | `lib/features/auth`; `docs/AUTH_ARCHITECTURE.md` | OPEN — evidence and production gate incomplete |
| 23 | E4-02 consultation intake/admin E2E | `lib/features/consultation`; `lib/features/admin` | OPEN — evidence and production gate incomplete |
| 24 | E4-03 applications/documents/private storage E2E | `lib/features/applications`; `lib/features/documents` | OPEN — evidence and production gate incomplete |
| 25 | E4-04 Admin role matrix & audit E2E | `lib/features/admin`; `docs/FINAL_SECURITY_ACCEPTANCE.md` | OPEN — evidence and production gate incomplete |
| 26 | E4-05 RTL/LTR/themes/accessibility | `lib/core/theme`; `lib/core/l10n` | OPEN — evidence and production gate incomplete |
| 27 | E5-01 CRM lifecycle | `lib/features/consultation`; `lib/features/admin` | OPEN — evidence and production gate incomplete |
| 28 | E5-02 notifications email/SMS/push preferences | `lib/features/notifications`; `lib/features/profile` | OPEN — evidence and production gate incomplete |
| 29 | E5-03 saved/read/user activity | `lib/features/feed`; `lib/features/dashboard` | OPEN — evidence and production gate incomplete |
| 30 | E5-04 business/AI/research dashboards | `lib/features/dashboard`; `docs/RELEASE_READINESS_MATRIX.md` | OPEN — evidence and production gate incomplete |
| 31 | E6-01 immutable release SHA & rollback | `docs/WEB_RELEASE.md`; `docs/ANDROID_RELEASE.md` | OPEN — evidence and production gate incomplete |
| 32 | E6-02 browser/viewport/language matrix | `docs/UI_UX_ROUTE_ACCEPTANCE.md`; `docs/CORRECTIVE_FEATURE_ACCEPTANCE_MATRIX.md` | OPEN — evidence and production gate incomplete |
| 33 | E6-03 native Android/iOS release & real devices | `docs/ANDROID_RELEASE.md`; `docs/IOS_RELEASE.md` | OPEN — evidence and production gate incomplete |
| 34 | E6-04 load/security/backup/SLO/UAT | `docs/FINAL_RELEASE_MATRIX.md`; `docs/FINAL_SECURITY_ACCEPTANCE.md` | OPEN — evidence and production gate incomplete |
| 35 | E6-05 Release A client handover | `docs/RELEASE_EXTERNAL_DEPENDENCIES.md`; `docs/FINAL_RELEASE_MATRIX.md` | OPEN — evidence and production gate incomplete |
| 36 | E7-01 payment provider/store compliance | `docs/PAYMENT_PRODUCTION_READINESS.md`; `docs/RELEASE_EXTERNAL_DEPENDENCIES.md` | OPEN — evidence and production gate incomplete |
| 37 | E7-02 subscriptions/billing/webhooks/taxes | `docs/AI_ENTITLEMENT_CONTRACT.md`; `docs/PAYMENT_PRODUCTION_READINESS.md` | OPEN — evidence and production gate incomplete |
| 38 | E7-03 entitlement financial integrity | `docs/AI_ENTITLEMENT_CONTRACT.md`; `lib/features/ai_assistant` | OPEN — evidence and production gate incomplete |
| 39 | E8-01 immigration profile/pathway assessment | `lib/features/profile`; `lib/features/visa` | OPEN — evidence and production gate incomplete |
| 40 | E8-02 case tracker/checklists/reminders | `lib/features/applications`; `lib/features/notifications` | OPEN — evidence and production gate incomplete |
| 41 | E8-03 OCR processing/review/privacy | `lib/features/documents`; `supabase/functions/document-intelligence/index.ts` | OPEN — evidence and production gate incomplete |
| 42 | E8-04 CV/SOP/document generator | `lib/features/documents`; `docs/REMAINING_PRODUCT_ROADMAP.md` | OPEN — evidence and production gate incomplete |
| 43 | E9-01 continuous policy knowledge/conflict monitor | `docs/KNOWLEDGE_INGESTION_CONTRACT.md`; `docs/KNOWLEDGE_RETRIEVAL_CONTRACT.md` | OPEN — evidence and production gate incomplete |
| 44 | E9-02 university/scholarship/calculators | `lib/features/visa`; `docs/REMAINING_PRODUCT_ROADMAP.md` | OPEN — evidence and production gate incomplete |
| 45 | E9-03 voice/multilingual handling | `lib/features/ai_assistant`; `docs/REMAINING_PRODUCT_ROADMAP.md` | OPEN — evidence and production gate incomplete |
| 46 | E9-04 recommendations/analytics/performance | `lib/features/dashboard`; `docs/REMAINING_PRODUCT_ROADMAP.md` | OPEN — evidence and production gate incomplete |
| 47 | E9-05 PRD long-tail integrations + final client acceptance | `docs/REMAINING_PRODUCT_ROADMAP.md`; `docs/RELEASE_EXTERNAL_DEPENDENCIES.md` | OPEN — evidence and production gate incomplete |

## Original feature scope vs technical components

| User-facing requirement | Main-branch implementation boundary | What is *not* established |
|---|---|---|
| Web + Android + iOS app | Flutter project; `lib/`, `web/`, `android/`, `ios/` | iOS signed device/store approval; App Store/Google Play release |
| Role-restricted User/Admin | `lib/features/auth`, `lib/features/admin`, Supabase RLS | Production role acceptance, real-mail recovery, two-user isolation |
| Visa destinations + structured content | `lib/features/visa`, localized tables | 18 steps / 8 requirements' **current official source evidence**, editorial approval for regulatory claims |
| Knowledge + research review/Feed | `supabase/functions/research-sync`, `lib/features/feed` | Full three-RAD-site corpus completeness; Admin-approved publication workflow E2E |
| AI assistant + model routing | `supabase/functions/ai-orchestrator`, `lib/features/ai_assistant` | Working funded provider credentials, accuracy evaluations, costs and fallback in live Production |
| Private user documents and OCR | `lib/features/documents`, `supabase/functions/document-intelligence` | Enabled and privately verified OCR processor, deletion and cross-user privacy E2E |
| Consultation, cases, CRM, notifications | Flutter feature directories; Supabase tables/RPCs | Staff workflows, SMS/push/email deliverability and client approval |
| Payment + entitlement integrity | `docs/PAYMENT_PRODUCTION_READINESS.md`, entitlement contract | Commercial provider account, merchant acceptance, plans/prices and webhook validity |
| Advanced pathway/case/CV/voice/university | Current `docs/REMAINING_PRODUCT_ROADMAP.md` | Complete working product implementation and regulatory fact-checking; treat roadmap as planned, not shipped |

## Reproducible audit closure for E0-03

- 47/47 gates represented in the table with verified repository-reference paths and evidence status.
- Distinguishes code existence, isolated CI, read-only live data, real-world delivery and external permissions.
- Preserves strict **no research/AI auto-publication** to Feed.
- Does **not** move any unproven runtime gates to Done, rewrite migration history, deploy Production, or claim owner approvals.
