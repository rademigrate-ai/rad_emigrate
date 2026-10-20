"""Package independently executed evidence; never changes application source."""
import collections,datetime,hashlib,json,pathlib,re,shutil,subprocess
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate');ROOT=BASE/'rad_final_independent_audit';RAW=BASE/'_final_independent_evidence_20261020'
OUT=ROOT/'FINAL_INDEPENDENT_AUDIT_20261020';E=OUT/'evidence';E.mkdir(parents=True,exist_ok=True)
SHA='1fe44f63d179263c5e719578bf7ebad0e17868d1'
def jsonfile(path):
    b=path.read_bytes()
    return json.loads(b.decode('utf-16') if b.startswith((b'\xff\xfe',b'\xfe\xff')) else b.decode('utf-8-sig'))
def read(name):return jsonfile(RAW/name)
def doc(name,text):(OUT/name).write_text(text.strip()+'\n',encoding='utf-8')
def loc(path,needle):
    lines=(ROOT/path).read_text(encoding='utf-8-sig').splitlines()
    return f'`{path}:{next((i for i,s in enumerate(lines,1) if needle in s),1)}`'
def table(headers,rows):return '| '+' | '.join(headers)+' |\n| '+' | '.join('---' for _ in headers)+' |\n'+'\n'.join('| '+' | '.join(str(x).replace('\n','; ').replace('|','/') for x in r)+' |' for r in rows)
for p in RAW.glob('*.json'):
    if p.name in ('hosted_catalog_metadata.json','catalog_drift_default_grants.json'):continue
    (E/p.name).write_text(json.dumps(jsonfile(p),indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
for runtime,prefix,names in [(BASE/'_local_audit_canonical','canonical',['start_report.json','canonical_report.json','http_acceptance.json','stop_report.json']), (BASE/'_local_audit_upgrade','upgrade',['start_report.json','reconstruct_report.json','compare_report.json','upgrade_report.json','stop_report.json'])]:
    for name in names:
        if (runtime/name).exists():shutil.copyfile(runtime/name,E/(prefix+'_'+name))
inventory=read('inventory.json');mig=read('migration_reconciliation.json');ci=read('ci_status.json')
clean=read('canonical_sql.json')['results'];upgrade=read('upgrade_sql.json')['results']
commands=[]
for p in RAW.glob('*.json'):
    try:r=jsonfile(p)
    except (ValueError,UnicodeError):continue
    if isinstance(r,dict) and 'command' in r:commands.append(r)
commands.append({'name':'deno_read_scope','candidate_sha':SHA,'command':'deno test --allow-env --allow-read=supabase/functions supabase/functions/tests','exit_code':0,'test_count':132,'basis':'Native process exit=0 and terminal 132 passed / 0 failed; raw log retained outside repository'})
commands.append({'name':'secret_scan','candidate_sha':SHA,'command':"python scripts/verify_local47_secret_scan.py --report ../_final_independent_evidence_20261020/secret_scan.json",'exit_code':0,'scanner_exit_codes':[1,1],'basis':'Wrapper completed; both scanner phases returned findings, never reported as zero findings'})
(E/'commands.json').write_text(json.dumps(commands,indent=2),encoding='utf-8')
manifest=[]
for p in sorted(RAW.iterdir()):
    if p.is_file():manifest.append({'file':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(E/'external_evidence_manifest.json').write_text(json.dumps({'directory':str(RAW),'candidate_sha':SHA,'files':manifest,'raw_logs_committed':False,'reason':'Raw CI/CLI logs can contain ephemeral local runtime material. Location-only scan reports, sanitized failure extracts and metadata are committed.'},indent=2),encoding='utf-8')
# Exact safe failure excerpts, rather than complete CI logs.
excerpt=[]
for job in ['118797557879','118797557906','118797558004','118797558085']:
    p=BASE/'_implementation_C002_C003_20261020'/('ci_job_'+job+'.log')
    if p.exists():
        lines=p.read_text(encoding='utf-8',errors='replace').splitlines()
        approved=[s for s in lines if any(t in s for t in ['RenderFlex overflowed','834 tests passed','Publish RPC lost human approval','Canonical clean-schema fingerprint differs','122 passed','Requires read access'])]
        excerpt.append({'job_id':job,'log_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'failure_lines':approved})
(E/'ci_failure_excerpts.json').write_text(json.dumps(excerpt,indent=2),encoding='utf-8')
finding_rows=[
('F01','High','Candidate omits the seven Codex follow-up migrations and contract/security regressions','Ancestry + file inventory; `9736540` and `24b3f6b` are absent','Codex backend / Antigravity integration','Integrate reviewed existing changes in an owner-controlled candidate; rerun every mandatory gate'),
('F02','High','Legacy approved-draft publication lost the human mutation marker and retains service EXECUTE',loc('supabase/migrations/20261019211000_security_quota_owner_and_publish_approved.sql','CREATE OR REPLACE FUNCTION public.publish_content_draft')+'; both SQL security suites and CI reconstruction fail','Existing Codex correction in `20261020111217_rad_restore_legacy_publish_privileges.sql`','Real human admin publishes approved draft with localization; service/ordinary/anonymous cannot; no auto-publish'),
('F03','High','Captured source snapshots can be changed after capture','`snapshot_immutability_probe.sql` raises AUDIT_MUTABLE_SOURCE_SNAPSHOT_ACCEPTED; transaction rolled back','Existing Codex integrity migration','Snapshot UPDATE/DELETE denied; fresh hash, proof, exact excerpt and scoped authority validation all pass adversarial tests'),
('F04','High','Currency RPC failures become fabricated fresh, provider-attributed local rates',loc('lib/features/visa/data/fx_repository.dart','return _defaultReferenceQuote')+'; production provider is selected by `fx_rate_controller.dart:9`','Antigravity frontend','Remove ordinary-runtime numeric fallback; malformed/unavailable remains unavailable; no fake freshness, provider, date or pair; decimal contract'),
('F05','High','Cost, pathway and university modules use hard-coded claims without field-level provenance',loc('lib/features/cost_calculator/data/cost_calculator_repository.dart','Official verified baseline')+'; `pathway_comparison/data/pathway_comparison_repository.dart`; `university_comparison/data/university_comparison_repository.dart`','Antigravity / content owner','Approved source snapshots, scope, effective/fresh dates and per-field evidence, or explicit unavailable; never invent prices/availability'),
('F06','Medium','Interview page overflows a 390px viewport by 345 pixels',loc('test/features/interviews/interviews_flow_test.dart','interviews page fits a mobile viewport')+'; independent local and CI full-suite failure','Freebuff UI / Antigravity integration','Fix owner-controlled layout, including long timezone labels; same test plus fa/en narrow/large-text variants pass'),
('F07','Medium','Consultation booking discards actual returned UUID and returns a timestamp-generated ID',loc('lib/features/booking/data/booking_repository.dart',"id: 'consultation-")+'; preferred start/timezone are returned locally but not in submitted RPC parameters','Antigravity frontend / Codex contract review','Use actual UUID response; label consultation intake honestly; preserve only server-accepted fields; no inferred appointment confirmation'),
('F08','High','Flutter AI client uses the legacy request path, not the implemented v1 copilot contract',loc('lib/core/services/ai/supabase_ai_service.dart',"'ai-orchestrator'")+'; absent x-rad-contract-version / request_key / authorized_data_scopes in outgoing request','Antigravity frontend + Grok Edge integration','Approve one request/response fixture; send version, idempotency key, explicit private scopes; integration tests exercise actual UI → v1 reservation/grounding/settlement'),
('F09','Medium','Legacy SQL acceptance and runtime ACL allowlist no longer agree with new APIs','Clean SQL: notification_preferences direct access and anonymous get_fx_quote API fail; not proof of unsafe public quote access','Codex existing corrected regression files / integration','Retain intended public getter allowlist; migrate preferences tests to CAS RPC; never weaken private function restrictions'),
('F10','Medium','CI omits filesystem read permission for ten source-inspection Deno tests; lint has 37 findings',loc('.github/workflows/ci.yml','deno test --allow-env')+'; 122 pass/10 fail with CI flags, 132/0 with scoped read permission; Deno 2.9.7 lint exit 1','Grok tests / Gemini CI','Scope permissions or remove redundant source assertions in owner review; use pinned toolchain; lint actual agreed scope'),
('F11','Review required','Booking/appointment caches and AI prompt draft are not keyed to authenticated identity',loc('lib/features/booking/presentation/providers/booking_controller.dart','final bookingHistoryProvider')+'; appointmentListProvider; ai_prompt_draft_provider global preference keys','Antigravity frontend privacy','Add account-A → logout → account-B regressions and clear/rekey private state. Source inspection confirms missing identity dependency; disclosure not dynamically reproduced here'),
('F12','High','Hosted ledger, active repository lineage and required additive components are not a deployable manifest','54 hosted versions versus 72 candidate files; hosted-only 27, repo-only 45 by exact version; not 45 unexecuted changes','Codex reconciliation / project owner','Approve per-version effects mapping and additive-only manifest; include absent CRM/payment/OCR/operations prerequisites or explicitly exclude disabled capabilities'),
('F13','Medium','Hosted grants remain broader than the client API needs; four private trigger definers have PUBLIC execute','Fresh hosted catalog: 36 TRUNCATE/TRIGGER/REFERENCES grant rows across six tables, 48 definers, all fixed search paths','Database security owner','Review/revoke unnecessary grants through reconciled additive work. These are grant findings, not demonstrated REST TRUNCATE or callable trigger exploits'),
('F14','Blocked prerequisite','Protected official-source operation and provider/notification readiness are not established','Official worker defaults disabled; no approved roots/pinned egress or real content corpus supplied; hosted only three legacy Edge functions','Project owner / Grok operational integration','Keep capabilities disabled; approve root/egress, real corpus and provider/transport initialization; review legacy hostname-only fetch DNS risks'),
('F15','High','Ordinary Visa article/search fallback fabricates verified content and relative fact-check dates',loc('lib/features/visa/data/canonical_pathway_repository.dart','return _fallbackCanonicalArticle')+'; '+loc('lib/features/visa/data/visa_search_repository.dart','return _fallbackSearch')+'; runtime fallback probe','Antigravity frontend','Move fixtures behind explicit test-only injection; unavailable/denied/malformed backend must not become published/verified content; never synthesize fact-checked dates or search timing'),
]
(E/'findings.json').write_text(json.dumps([dict(zip(['id','severity','finding','evidence','owner','acceptance'],r)) for r in finding_rows],indent=2),encoding='utf-8')
doc('README.md',f'''# Independent final release audit — RAD Emigrate

**Integration Review: GO. Staging: NO-GO. Production: NO-GO.** Integration review permits examining and reconciling this evidence; it is not acceptance of the candidate or permission to deploy.

Application candidate tested independently: `{SHA}` (`feat/rad-unified-release-candidate`). Isolated audit branch: `audit/final-independent-20261020`. All application/migration tests refer to that immutable source commit. Later audit commits contain reports and reproduction tools only and must not inherit a fictitious full-suite PASS.

The candidate lacks Codex's completed security follow-ups. Local and GitHub Flutter suites both have **834 passes / 1 failure** (interview mobile overflow). GitHub CI has **3 successful jobs / 4 failed jobs**. All 72 candidate migrations replay, but security acceptance fails afterward. A production-shaped local reconstruction matches ten catalog dimensions, applies twelve forward files, then also fails required acceptance. No hosted SQL was applied.

Additional source inspection found ordinary Visa article/search fallbacks marked verified with synthesized fact-check dates. Together with fabricated fresh FX fallback and hard-coded cost/comparison assertions, this blocks evidence-backed product readiness.

Positive evidence: format 394 files unchanged; analysis no issues; 43 Python tests; corrected-scope 132 Deno tests; 28 real Auth/RLS/HTTP checks; mixed legacy/v1 concurrency admits exactly two of ten at a limit of two; real loopback Deno handlers pass four Auth/reservation/no-evidence checks. These do not cancel the failing gates.

Read [branch and ownership inventory](01_BRANCH_OWNERSHIP.md), [security findings](02_SECURITY.md), [migration reconciliation](03_MIGRATIONS.md), [feature and contract audit](04_FEATURES_CONTRACTS.md), [test evidence](05_TESTS.md), [release checklist](06_RELEASE_GATES.md), and [integration owner handoff](07_OWNER_HANDOFF.md).

Scope limits: fresh hosted reads queried catalog/ledger metadata, not user/business rows or secret stores. No hosted mutation, Edge deployment, Feed publication, production deployment, shared-branch merge, main merge, force-push, or dirty-agent reset occurred. All synthetic SQL/HTTP writes used dedicated loopback containers owned by this audit.

Evidence captured on 2026-10-20. Branches/worktrees can move later. Uncommitted work is inventory evidence, never treated as an integrated commit. No Antigravity/Grok live messaging session is verified; this packet and the current project conversation are the authorized review channel.
''')
branch_rows=[]
for r in inventory['branches']:
    local=r['local']['output'] if r['local']['exit_code']==0 else 'absent'
    remote=r['remote']['output'] if r['remote']['exit_code']==0 else 'not published under this origin ref'
    branch_rows.append((r['branch'],local,remote,', '.join(k for k,v in r['ancestry'].items() if v)))
branch_rows.append(('main / deployed Render','95e1fdaac74d36ca1c91f2d9d897ff7686dc3ffb','95e1fdaac74d36ca1c91f2d9d897ff7686dc3ffb','Candidate is 20 commits ahead by rev-list; no main commits missing from candidate'))
dirty=[r for r in inventory['worktrees'] if r['status']['output']]
doc('01_BRANCH_OWNERSHIP.md',f'''# Branch, integration and ownership inventory

`git fetch origin --prune` completed before this inventory. {len(inventory['worktrees'])} local worktrees were inspected; {len(dirty)} had changes at capture. See `evidence/inventory.json` for exact paths, statuses, upstream/ahead-behind, commit timestamps and every dirty file. Other agents' changes were read only.

{table(['Branch','Local HEAD','Fetched origin HEAD','Reference commits present by ancestry'],branch_rows)}

Owner attribution follows explicit project roles and worktree/branch names: Codex backend/security; Antigravity Flutter/contracts and unified candidate; Grok services and Grok integration worktrees; Freebuff newer feature UI; Gemini CI/review. Worktree names do not prove a live agent lease. No direct agent session exists, so no assertion is made that an agent is currently idle or actively editing a specific file.

Candidate `1fe44f6` includes Grok `c57b56d`, Antigravity adapter `e80f106`, prior domain/Flutter work (`c710893`, `843ea7c`, `b97c8f0`) and case identity fix `a9969c1`. The newer origin Flutter E2E commit `f616078a56eb8159030911d38b66b1e961504dba` is also an ancestor despite the older local worktree HEAD. Candidate does **not** include Codex `9736540` or `24b3f6b`; all seven 20261020 SQL files and corrected wire/security regressions are absent.

Read-only Render verification in previously authorized workspace Rad confirms static service `srv-db0p4e9srm7s738jam10` is live at `95e1fdaac74d36ca1c91f2d9d897ff7686dc3ffb`, matching fetched origin/main. Auto-deploy is off; configured branch is main; build is `bash scripts/build_web_render.sh`, publish directory `build/web`. The tested candidate is not deployed. Five deployment metadata rows were inspected; no environment values, deployments or settings were read/changed. See `render_readonly.json`. Hosted Supabase lists only research-sync v4 (gateway JWT off, handler authorization required), ai-orchestrator v11 and document-intelligence v3 (gateway JWT on); new candidate workers are not deployed there.

Freebuff's current booking/interview files are untracked in its own worktree. Read-only comparison shows booking implementation and interview tests agree with the candidate; `interviews_page.dart` differs: the candidate adds a future quarter-hour seed and replaces one Wrap with a Column. Therefore substantial Freebuff recovery was incorporated, but its files cannot be represented as a new published Freebuff commit. The independent mobile overflow test still fails. Nothing was copied or cherry-picked from those dirty directories.

Preserved unresolved work includes the `UU` timezone engine in `rad_pr49_time_review_20261018`, staged UI changes in `rad_integrate68_readonly_20261018`, untracked migrations in `rad_c002_c003_local` and `rad_grok_final_recovery`, and dirty routing tests in `rad_integration_a003_unified`. Their exact statuses remain in the inventory. Do not reset, move, stage or publish them through this audit.

The audit branch began at exact candidate SHA before all verification. Only this new checkout and its two marked local runtimes were written. Generated Flutter plugin files in the audit checkout are tracked separately from actual source changes and checked for line-ending-only effects before report commit.
''')
doc('02_SECURITY.md',f'''# Independent security findings

{table(['ID','Severity','Finding','Evidence','Owner','Acceptance gate'],finding_rows)}

Verified positives: Auth signup and two real JWTs enforce owner reads; direct role escalation UPDATE and orphan INSERT are denied; safe owner profile completion succeeds; private/Vault schemas are absent from REST; draft tables deny clients; foreign AI message/session access and consultation mutation are denied. Both ordinary and mixed quota races have bounded persisted reservations, body-key conflicts return conflict, and settled reservations cannot be settled twice. These were executed in this audit (`canonical_http_acceptance.json`, `quota_concurrency.json`).

Quota NULL validation fails with SQL 23502 for NULL body hash rather than the contract's PT422. That is a confirmed error-contract defect, not evidence that a NULL body bypasses the NOT NULL constraint. The dedicated newer regression fails on both local database shapes. The atomic concurrency positive result remains valid independently.

Publication regression distinction: the later publisher still checks admin role and approved status, but lost the required human mutation context and localization insert while retaining service EXECUTE. Tests detect the broken human-only publication invariant. No successful unauthorized Feed publication was demonstrated or attempted against hosted data. Research snapshot ingest creates review drafts; passing stage2 and research handler tests do not certify the missing newer official-source workflow.

Fresh production metadata at `{read('hosted_snapshot.json')['captured_at']}` shows **57/57 public tables with RLS enabled**, 48 SECURITY DEFINER functions, four private trigger routines with PUBLIC execute and zero definers missing a fixed search path. All eleven comparable metadata dimensions match the earlier production capture after representation-only normalization. The earlier twelve RLS-disabled tables belong to the captured staging finding; no claim is made that staging is repaired or currently safe.

Payment SQL/handler sandbox tests pass on the clean lineage. The payment routine is absent from the production-shaped baseline plus the twelve candidate forward files, as are optional OCR/incident foundations. Those attempted upgrade tests fail; they are not counted as passes, and no historical SQL was replayed there to manufacture missing capabilities. Live payment, webhooks and notification delivery remain unverified/disabled.

Secrets: pinned offline Gitleaks returned eight snapshot and 23 history findings. Every reported location was inspected independently in its source commit. Twenty-two metadata occurrences match actual SQL SHA-256 digests (including line-ending variants), one is a preference-key identifier, and eight are graphify stat-index metadata. Automated result remains FINDINGS_REQUIRE_REVIEW; manual noncredential review is recorded separately. No scanner policy/ignore change or history rewrite was used. This scope excludes ignored environment files, deployed bundles and external secret stores.

Public grant findings require least-privilege review even with RLS enabled. TRUNCATE is not row-filtered, but ordinary PostgREST does not expose arbitrary SQL/TRUNCATE, and PostgreSQL trigger-returning functions are not directly callable as normal RPCs. This audit therefore does not inflate grant metadata into a proven public destructive exploit. See [Supabase RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security) for the distinction between grants and row policies.
''')
doc('03_MIGRATIONS.md',f'''# Migration reconciliation and rehearsal

Current hosted project: `inshddthftkhcdosoqcn`. Queries were SELECT-only catalog/ledger queries. Fresh production schema metadata matches the captured baseline across tables, columns, constraints, indexes, policies, effective table/column grants, functions (definition MD5 plus owner/ACL/config), triggers, Storage and default grants. Default ACL JSON-array versus PostgreSQL-array text is normalized; no semantic drift is hidden.

Candidate has **72 SQL files**; hosted ledger has **54 versions**. Exact-version sets contain **27 hosted-only** and **45 repository-only** entries. These are lineage aliases and content/effect differences, not a deploy list. Name-based statement hash audit reports **29 text matches, 13 text/storage-format differences, 2 multipart histories not comparable, 10 unmatched names, 17 version aliases**. The script intentionally exits 2 / NO_GO. Hash matches alone do not prove equivalent effects or authorize repair. See exact versions, file digests and results in `migration_reconciliation.json`, `hosted_statement_hashes.json`, `statement_comparison.json`.

Clean isolated runtime: `rad_audit_canonical`, DB `127.0.0.1:62322`, API `127.0.0.1:62321`. All 72 files applied in order, recorded by file digest, with cron disabled after each file. **DDL replay PASS; security/acceptance FAIL.** The separate CI clean-schema fingerprint differs only in the audited trigger dimension (`4e10...` expected versus `e351...` actual); do not replace that expectation until the actual trigger effect is reviewed.

Production-shaped isolated runtime: `rad_audit_upgrade`, DB `127.0.0.1:63322`. Reconstructed production objects and synthetic observed ledger from metadata only; no business/Auth/Vault data or executable production cron commands. Ten catalog dimensions match; CLI dry-run finds zero historical versions pending against local ledger markers. Applied **12 forward files beginning 20261019204906**, never historical migrations. **Additive DDL PASS; acceptance FAIL.** This is a rehearsal manifest, not an approved hosted rollout plan.

Source snapshot was refreshed through read-only hosted metadata before relying on the older reconstruction input. Platform Auth/Storage patch versions and inactive no-op cron remain explicit local differences. Native CLI 2.121.0 differs from CI 2.119.0. The external configurable harness was used because the candidate's old helper hardcodes another agent's runtime; its digest and exact guard-preserving adapter are recorded. Application/migration files were not altered.

After retaining all evidence, both audit-owned local stacks were stopped without backup. Their external runtime directories and manifests remain. No other local Supabase stack was stopped or changed by this audit. Reproduction requires recreating an owned disposable stack; do not target an existing agent's runtime.

Known next prerequisite: reconcile and owner-review existing Codex seven-file delta, CRM events, optional payment/OCR/operations effects and migration ordering. The clean lineage has foundations that the captured production baseline lacks. Do not execute the historical local47 migrations against production or treat already-present functions as permission to repair the hosted ledger. No competing SQL file was authored in this audit.

Before staging: approved hosted-versus-candidate effects mapping; exact normalized digest manifest; additive-only transaction/lock assessment; reviewed data initialization; backup/restore and abort criteria; staging project identity and procedure approval. Before production: repeat drift reads immediately before authorized rollout, confirm required initialization and operational readiness, and obtain release authorization. This audit performs none of those hosted mutations.
''')
features=[
('Booking / consultation','/booking; /booking/service/:serviceId; /consultation','Partial: real authenticated consultation RPC and RLS; no staff booking catalog/RPC installed','No invented price/duration, capability/loading/error/guest states and validations implemented; returned consultation UUID is ignored, preferred slot fields are not persisted; account-cache review needed'),
('Interview scheduling','/interview-scheduling and /interviews','Partial / unavailable backend: two parallel UI/repository contracts; no installed scheduling RPCs','Freebuff domain validation, timezone/DST and external-embassy refusal exist; fa RTL test passes, mobile overflow fails; older page uses Navigator.pushNamed with a GoRouter application, and broad catches flatten permission/network failures'),
('Immigration cost calculator','/calculator/cost','Not source-backed / release blocked','Static fee/fund amounts, asserted official schedules and generic numeric fallback; no per-item source/effective dates; unit/widget passes validate implementation, not factual accuracy'),
('Country / pathway comparison','/compare/pathways','Not source-backed / release blocked','Three hard-coded pathway rows and processing times; no evidence/freshness/scope model; comparison rendering and localization are present'),
('University comparison','/compare/universities','Not source-backed / release blocked','Static rank/tuition/admission/scholarship assertions; official homepage URL is not evidence for each field; no verified program/year/fee category scope'),
]
doc('04_FEATURES_CONTRACTS.md',f'''# Feature, API and integration audit

{table(['Feature','Routes','Backend/data verdict','UI and remaining defects'],features)}

Routing is registered in `lib/core/routing/app_router.dart:148` onward. Booking/explore pages are public and submissions check Auth. `/interviews` and nested booking destinations are registered but missing from auth_redirect's known destination set; this can lose an intended login return route. The scheduling page's consultation button uses `Navigator.pushNamed` despite GoRouter navigation elsewhere. These are frontend-owned findings requiring route-level regression; an actual unauthorized scheduling capability is not inferred.

Five-feature tests cover English/Persian labels, forms, mocked repository states and some narrow-screen behavior. They are not evidence of live slots, approved pricing, complete data provenance, physical device behavior or a working hosted booking system. Full-suite interview overflow is a mandatory failure. Manual physical-device/assistive-technology coverage remains NOT VERIFIED.

Visa/CMS: canonical article/head/revision/section and independent related-article structures, review/approval, source merge manifest and published-only search exist. Three candidate rad SQL suites pass on both shapes. However, ordinary frontend RPC errors or an uninitialized service route to canonical/search fixtures, some marked verified/published, with DateTime.now-derived fact-check dates and a fabricated tookMs value. These are not guarded by a test/demo environment. This bypasses the product's evidence semantics even though database RLS remains intact. Search is also hardcoded to locale fa rather than using the requested UI locale. Remove these fallbacks through the frontend owner, preserving unavailable/denied/error states.

The missing follow-ups implement immutable evidence, exact projection, leased source-change recording, section hashes, resume/bookmarks, comments and search performance corrections. Their absence and the missing real approved content corpus mean feature completion cannot be certified. Never auto-publish or fabricate immigration facts.

Feed: bottom navigation uses Feed and Cases is under Profile; saved/read interactions exist. New Feed review tests pass, but legacy CMS publication invariant fails. Notification preference revisions/outbox and sandbox handling are implemented in differing lineage layers; direct legacy test writes are incompatible and actual delivery/targeting is unverified. Capabilities must remain unavailable until approved initialization/transport.

RAD AI: visible assistant is text-only. Voice domain files/tests exist, but this audit found no voice/image upload activation in the assistant flow. Actual loopback handlers authenticate, reserve quota and return an insufficient-evidence response without a provider call. The Flutter adapter sends legacy payloads, so v1 tool permissions, request_key, structured context and personalization are not integrated from the UI. Case reads in v1 use actor JWT plus explicit owner predicate; local-only immigration profile is honestly unavailable to backend tools. No broad private-data consent is inferred.

Cases/Profile: authenticated case identity fix is included; existing four identity regression cases pass in the CI full suite. Local profile role escalation and foreign consultation/session writes are denied. Pending guest AI drafts intentionally survive auth transitions in global preferences; privacy expectations for account switching need explicit review. Booking/appointment FutureProviders do not depend on actor identity; disclosure is a source-backed risk awaiting a focused dynamic regression, not a claimed verified exploit.

Contract reconciliation must use `supabase/contracts/rad_v1.json` plus actual SQL-generated fixtures on Codex branch, not frontend examples alone. Candidate list responses are implemented as data.items while some registry definitions remain array-shaped; Codex's corrected registry/wire fixtures are missing. Currency needs exact decimal strings, provider/date/basis and explicit unknown/stale/unavailable states; IRT is display arithmetic only. Search uses published full-body sections, stable section IDs, cursor/envelope/error semantics and UTF-16 highlight ranges; ranking/real multilingual gold evidence is not verified here.

Frontend owner Antigravity and final project owner should review request/response schemas, RPC/Edge names, Auth/RLS boundaries, error states, cursors and immutable revision keys together before integration. The current project chat is the agreed channel. This packet does not claim that contract approval already happened.
''')
def counts(rows):return dict(collections.Counter(r['status'] for r in rows))
testrows=[]
for name,label,extra in [('dart_format','Formatting','394 files, 0 changed'),('flutter_analyze','Flutter analysis','No issues'),('flutter_test','Full Flutter tests','834 pass / 1 fail (mobile interview overflow)'),('web_build','Local web release build','non-production configuration'),('android_debug','Local Android debug build','arm64; non-production configuration'),('deno_lint','Deno lint','37 findings / 37 files; native Deno 2.9.7'),('deno_test','Deno with CI flags','122 pass / 10 permission failures'),('python_tests','Python unittest','43 pass'),('recovery_redirect','Recovery redirect check','normalization assertions')]:
    p=RAW/(name+'.json')
    r=read(p.name) if p.exists() else {}
    testrows.append((label,'PASS' if r.get('exit_code')==0 else 'FAIL' if r.get('exit_code') is not None else 'NOT COMPLETE',r.get('exit_code','not recorded'),extra))
testrows += [('Deno with scoped read','PASS',0,'132 pass / 0 fail; does not repair CI'),('Actual handler loopback HTTP',read('edge_http.json')['status'],0,'4 checks; Auth → reservation → no-evidence result; external net denied'),('Auth/RLS/RPC HTTP','PASS',0,'28 real local checks'),('Mixed quota concurrency','PASS',0,'two runs, ten concurrent calls each, two admitted and persisted'),('Clean SQL suites','FAIL','see per-suite JSON',str(counts(clean))+'; includes one newer external NULL regression'),('Upgrade SQL suites','FAIL','see per-suite JSON',str(counts(upgrade))+'; includes absent optional foundations and newer NULL regression'),('Snapshot immutability probe','FAIL',3,'privileged mutation accepted; rolled back'),('Runtime fallback regression','FAIL',1,'0 pass / 3 fail; FX/canonical/search synthetic trust reproduced without network'),('Pinned Gitleaks','FINDINGS','scanner 1/1; wrapper 0','8 snapshot + 23 history; independent manual noncredential review PASS')]
doc('05_TESTS.md',f'''# Independent test evidence

Every application test below uses immutable `{SHA}`. Native local verification and GitHub CI are separately recorded. Raw logs remain at `{RAW}` with byte counts/SHA-256 in `external_evidence_manifest.json`; sanitized machine reports are committed beside this document. Later report commits do not change tested application source.

{table(['Check','Local result','Exit','Count / limitation'],testrows)}

CI run: [{ci['runs'][0]['id']}]({ci['runs'][0]['html_url']}) — final **failure** at `{SHA}`.

{table(['Job','GitHub conclusion','Link'],[(j['name'],j['conclusion'],j['html_url']) for j in ci['jobs']])}

Reproduced failures: Flutter interview 390px overflow; Deno missing --allow-read; clean-schema trigger fingerprint mismatch; migration reconstruction lost human-publish marker. Additional SQL failures are preserved individually, including privilege allowlist/test-contract mismatches. Optional production-shaped payment/OCR/incident suites were attempted and failed due absent foundations; this audit does not relabel those attempts as passes.

Exact native commands, timestamps, durations, exits and log digests are in `commands.json`. SQL runner invocation and every source/test file digest are recorded in `canonical_sql.json`, `upgrade_sql.json`, canonical/upgrade manifests and copied reproduction tools. Platform tools: local Flutter 3.47.6 / Dart 3.13.5; Deno 2.9.7; native Supabase 2.121.0 / PostgreSQL client 17; GitHub workflow pins Flutter 3.47.6, Deno 2.5.4, Supabase 2.119.0. Do not attribute a native-tool PASS to a different CI toolchain.

Representative reproducible application checks in a separate checkout of the candidate:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --release --no-pub --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder
flutter build apk --debug --no-pub --target-platform android-arm64 --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder
deno lint supabase/functions
deno test --allow-env supabase/functions/tests
deno test --allow-env --allow-read=supabase/functions supabase/functions/tests
python -m unittest discover -s scripts/tests -v
```

`tools/` contains the exact local audit adapters. They deliberately bind to this workspace, immutable source SHA and owned runtime markers; do not remove those guards to run in shared/hosted environments. Original candidate helper hardcodes another checkout's runtime, so it was not used to mutate it. The newer external harness source SHA is recorded. Recreate new disposable identities and review adaptations if moving the workspace.

NOT VERIFIED: production provider success, external source egress/root proof, push/email delivery, live payment settlement, real booking/interview scheduling, factual immigration/tuition/fee data, search gold/capacity corpus, physical Android/iOS/assistive device testing, Android signed release, full Flutter-to-hosted-v1 E2E. Mocked handler/source-inspection tests do not constitute those gates.
''')
doc('06_RELEASE_GATES.md',f'''# Reproducible release gates

{table(['Gate','Verdict','Basis'],[('Integration Review','GO','Evidence and existing completed branch deltas are reviewable; unresolved defects remain'),('Candidate integrated acceptance','NO-GO','Missing Codex deltas, four failed CI jobs and confirmed source/UI/integration defects'),('Staging','NO-GO','Mandatory gates do not pass on the same final candidate; staging procedure approval still required'),('Production','NO-GO','Migration reconciliation/initialization, operations and release authorization absent'),('Android debug build','See test evidence','Build output is a development artifact, never signed-release approval'),('Android signed release','NO-GO','Permanent application identity and owner-supplied signing absent; guard intentionally blocks packaging')])}

Checklist for the integration owner, in dependency order:

- [ ] Agree one immutable combined source commit, actual agent ownership and a complete manifest. Do not merge this report as a substitute for integrating backend code.
- [ ] Reconcile existing Codex `9736540` and `24b3f6b` effects with Antigravity/Grok. Avoid recreating their seven SQL files. Keep extra Grok lifecycle coverage and address scoped-read CI requirements explicitly.
- [ ] Fix human-only publication, immutable official evidence, NULL validation and intended definer ACLs; rerun positive and negative real-role tests. Never weaken RLS or make private routines public to satisfy a test.
- [ ] Correct currency fabrication and unsourced cost/comparison output. Use approved evidence models or unavailable states.
- [ ] Resolve AI v1 request/version/consent wiring and booking actual-ID/history semantics with Antigravity; add account-switch and route-return regressions.
- [ ] Resolve interview mobile overflow and test fa/en, long timezones, narrow widths, 200% text and loading/error/empty states.
- [ ] Approve hosted effects mapping, required component manifest and additive-only migration plan. Rehearse on clean and fresh production-shaped disposable databases. Confirm migration bytes and no hosted drift.
- [ ] All format/analyze/full Flutter, Deno lint/typecheck/tests, real Edge/Auth/RPC security, quota races, research-to-draft and no-auto-publication, SQL security, clean/additive rehearsals, secret review, web/Android builds and GitHub CI pass on the **same combined source commit**.
- [ ] Validate approved source corpus, authority roots, pinned egress, provider credentials/limits, notification transport, operational monitoring, rollback/restore and disabled-capability initialization in staging.
- [ ] Obtain explicit staging procedure approval before deployment. This audit did not deploy.
- [ ] Obtain permanent Android application ID, protected signing, device testing and release distribution review. Debug build is insufficient.
- [ ] Repeat pre-production drift/initialization verification, approve operational readiness and obtain final production release authorization.

Existing successful Codex branch CI at `24b3f6b` is historical supporting evidence only; it is not the unified candidate's CI and does not override this run's failure. No gate is implicitly approved by an elapsed wait, successful build or report publication.
''')
doc('07_OWNER_HANDOFF.md',f'''# Integration owner handoff — current project conversation

Audited source: `{SHA}`. Audit/report branch: `audit/final-independent-20261020`. Candidate CI: {ci['runs'][0]['html_url']} — four failing / three successful jobs.

No application fix or new migration was authored in this independent audit: the confirmed backend defects already have existing Codex-owned corrections; UI/Edge/CI defects are within explicitly assigned Antigravity/Freebuff/Grok/Gemini areas. Dirty worktrees were not overwritten, and unfinished changes were not cherry-picked or merged. This is an ownership decision, not a claim that defects were fixed.

{table(['Priority / owner','Concrete next task','Acceptance'],[('P0 — Antigravity integration + Codex','Reconcile existing seven-file backend delta `9736540` + `24b3f6b` with candidate; include contract fixtures and tests, not only SQL','Human publish, evidence immutability, input errors, ACLs and all mandatory SQL gates pass on combined commit'),('P0 — Antigravity','Remove FX fabricated fresh fallback; stop hard-coded official fee/tuition/rank/pathway claims','Unavailable states or reviewed provenance; negative-network and malformed-contract regressions'),('P0 — Antigravity + Grok','Wire actual v1 AI payload/header/consent and agree exact contracts','Real UI → handler → Auth/RPC → reservation/grounding/settlement test; no image/voice activation'),('P1 — Freebuff + Antigravity','Fix 345px interview overflow; consolidate two scheduling routes/contracts; correct booking UUID and return routes','Full 835-case suite green plus narrow/RTL/large-label regression'),('P1 — Grok + Gemini','Correct Deno read permission and agreed lint scope; preserve meaningful lifecycle tests','Pinned toolchain local and GitHub gates pass'),('P1 — Antigravity privacy','Key cached booking/appointment/private drafts to authenticated identity','Account A → logout → B cannot see/use A data; pending guest-draft behavior approved'),('Prerequisite — Codex + owner','Reconcile ledger aliases, existing effects and missing optional backend foundations into approved additive manifest','Fresh hosted reads + clean/additive rehearsals + reviewed initialization/rollback'),('Prerequisite — owner / operations','Approve authority roots, pinned egress, evidence corpus, providers/transports and deployment procedure','Staging prerequisites verified before explicit deployment approval')])}

For the frontend contract review, use existing backend `supabase/contracts/rad_v1.json`, SQL-generated wire fixtures and `research_worker_base.json` from Codex's completed branch. The review must cover endpoint/RPC names, closed request/response shapes, auth/RLS, errors, pagination, revision/idempotency keys and null/unavailable semantics. Antigravity and the project owner have not signed off through this audit session. Present this document in the current chat; no unverified external agent channel was used.

Production and staging remain NO-GO. Integration review remains GO. The next integration owner should report the new combined SHA, not reuse test claims from either source branch.
''')
# Preserve all exact helper sources for reproduction, without credentials.
T=OUT/'tools';T.mkdir(exist_ok=True)
for name in ['final_inventory.py','final_catalog_compare.py','final_checks.py','final_rehearsal.py','final_upgrade_run.py','final_sql_checks.py','final_http_probe.py','final_quota_concurrency.py','final_snapshot_probe.py','final_edge_http.py','final_scan_review.py','final_validate.py','package_final_audit.py']:
    shutil.copyfile(BASE/'_implementation_C002_C003_20261020'/name,T/name)
shutil.copyfile(RAW/'snapshot_immutability_probe.sql',T/'snapshot_immutability_probe.sql')
shutil.copyfile(RAW/'runtime_fallback_probe_test.dart',T/'runtime_fallback_probe_test.dart')
shutil.copyfile(RAW/'hosted_readonly_queries.sql',T/'hosted_readonly_queries.sql')
for rel in ['build/web/index.html','build/web/main.dart.js','build/app/outputs/flutter-apk/app-debug.apk']:
    p=ROOT/rel
    if p.exists():
        artifact={'candidate_sha':SHA,'file':rel,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'configuration':'Non-production placeholder URL/key; debug APK is not signed-release approval'}
        (E/('artifact_'+p.name.replace('.','_')+'.json')).write_text(json.dumps(artifact,indent=2),encoding='utf-8')
summary={'source_candidate_sha':SHA,'generated_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'ci_status':ci['status'],'clean_sql':counts(clean),'upgrade_sql':counts(upgrade),'gate':{'integration_review':'GO','staging':'NO-GO','production':'NO-GO'},'docs':[p.name for p in sorted(OUT.glob('*.md'))]}
(E/'audit_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8');print(json.dumps(summary,indent=2))
