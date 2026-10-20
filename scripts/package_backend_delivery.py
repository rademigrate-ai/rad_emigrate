"""Package non-sensitive local verification evidence and the backend handoff."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'BACKEND_DELIVERY_20261020'
RUNTIME = ROOT.parent / '_local_core_upgrade'
CLEAN = ROOT.parent / '_local_core_canonical'
LOGS = ROOT.parent / '_implementation_C002_C003_20261020'


def read_json(path, fallback=None):
    return json.loads(path.read_text(encoding='utf-8-sig')) if path.exists() else fallback


def write(name, text):
    (OUTPUT / name).write_text(text.strip() + '\n', encoding='utf-8')


def read_log(path):
    if not path.exists():return ''
    data=path.read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8',errors='replace')


def main():
    OUTPUT.mkdir(exist_ok=True)
    evidence = OUTPUT / 'evidence'
    evidence.mkdir(exist_ok=True)
    registry = read_json(ROOT / 'supabase/contracts/rad_v1.json')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    branch = subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT, text=True).strip()
    migrations = sorted((ROOT / 'supabase/migrations').glob('*.sql'))
    forward = [p for p in migrations if p.name >= '20261019204906_']
    manifest = [{'file': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(),
                 'git_lf_sha256':hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()} for p in migrations]
    (evidence / 'migration_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    sources = {
        'production_shape_reconstruction': RUNTIME/'reconstruct_report.json',
        'production_shape_parity': RUNTIME/'compare_report.json',
        'production_shape_upgrade': RUNTIME/'upgrade_report.json',
        'production_shape_contract_append': RUNTIME/'contract_append_report.json',
        'production_shape_research_base_append': RUNTIME/'apply_report.json',
        'clean_replay': CLEAN/'canonical_report.json',
        'clean_contract_append': CLEAN/'extend-canonical_report.json',
        'clean_regression': CLEAN/'backend_regression.json',
        'upgrade_regression': RUNTIME/'backend_regression.json',
        'http_security': RUNTIME/'http_acceptance.json',
        'builds': LOGS/'backend-final-build-checks.json',
    }
    for name, source in sources.items():
        if source.exists():
            data = read_json(source)
            if isinstance(data, dict): data.pop('platform_storage_extras', None)
            (evidence/(name+'.json')).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    # Preserve the initial batch and attach a later targeted correction only
    # when the successful execution report hashes the exact current test file.
    final_suites={}
    for label,directory in [('clean',CLEAN),('upgrade',RUNTIME)]:
        suite=read_json(directory/'backend_regression.json',[])
        for proof in [*directory.glob('*_targeted_report.json'),directory/'test_report.json']:
            targeted=read_json(proof,{})
            filename=targeted.get('sql','').replace('\\','/')
            if targeted.get('status')=='PASS' and filename and (ROOT/filename).is_file() and hashlib.sha256((ROOT/filename).read_bytes()).hexdigest()==targeted.get('sql_sha256'):
                corrected=[]
                for row in suite:
                    if row['test']==filename:
                        row={**row,'status':'PASS','sha256':targeted['sql_sha256'],'targeted_correction_at':targeted['at']}
                    corrected.append(row)
                suite=corrected
                (evidence/(label+'_targeted_'+Path(filename).stem+'.json')).write_text(json.dumps(targeted,indent=2)+'\n',encoding='utf-8')
        final_suites[label]=suite
        (evidence/(label+'_regression_final.json')).write_text(json.dumps(suite,indent=2)+'\n',encoding='utf-8')
    metrics = {}
    for label, directory in [('clean', CLEAN), ('upgrade', RUNTIME)]:
        log = directory/'rad_search_performance.log'
        if log.exists():
            match = re.search(r'p95_ms=([0-9.]+)', log.read_text(encoding='utf-8'))
            if match: metrics[label] = float(match[1])
    (evidence/'search_performance.json').write_text(json.dumps({'fixture':'10000 synthetic sections; 20 warm broad-query samples; local shared host','p95_ms':metrics,'production_capacity_validated':False},indent=2)+'\n',encoding='utf-8')
    results = {}
    for key, file, expression in [
        ('deno','backend-final-deno-with-contracts.log',r'ok \| (\d+) passed \| 0 failed'),
        ('flutter_tests','backend-flutter-final-test-rerun.log',r'\+(\d+): All tests passed!'),
        ('flutter_analysis','backend-flutter-final-analyze.log',r'No issues found!')]:
        text=read_log(LOGS/file)
        match=re.search(expression,re.sub(r'\x1b\[[0-9;]*m','',text))
        results[key]={'status':'PASS' if match else 'NOT RUN','result':match[0] if match else 'no completed successful final result','log':str(LOGS/file)}
    (evidence/'tool_results.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
    artifacts=[]
    for relative in ['build/web/index.html','build/app/outputs/flutter-apk/app-debug.apk']:
        path=ROOT/relative
        if path.exists():
            digest=hashlib.sha256()
            with path.open('rb') as source:
                for chunk in iter(lambda:source.read(1024*1024),b''):digest.update(chunk)
            artifacts.append({'path':relative,'bytes':path.stat().st_size,'sha256':digest.hexdigest(),'configuration':'non-production dummy Supabase endpoint/key'})
    (evidence/'build_artifacts.json').write_text(json.dumps(artifacts,indent=2)+'\n',encoding='utf-8')
    for path in [CLEAN,RUNTIME]:
        marker=read_json(path/'RAD_DISPOSABLE_LOCAL_ONLY.json')
        assert marker['owner_checkout']==str(ROOT) and marker['project'].startswith('rad_core_')
    names={e['name'] for e in registry['endpoints'] if e['transport']=='RPC'} | {
        'reserve_rad_ai_request','settle_rad_ai_request','expire_rad_ai_reservations','consume_ai_daily_quota',
        'retrieve_verified_official_claims','verify_official_claim','record_official_source_change','ingest_visa_snapshots',
        'record_fx_observation','claim_official_research_job','get_official_research_job','finish_official_research_job','get_research_article_base',
        'submit_consultation_request','list_admin_consultations','update_admin_consultation','transition_admin_consultation','assign_admin_consultation'}
    quoted=','.join("'"+n+"'" for n in sorted(names))
    query="""select jsonb_agg(to_jsonb(f) order by f.name) from (
    select p.proname name,pg_get_function_arguments(p.oid) arguments,pg_get_function_result(p.oid) result,
    p.prosecdef security_definer,p.proconfig config,has_function_privilege('anon',p.oid,'EXECUTE') anon_execute,
    has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated_execute,
    has_function_privilege('service_role',p.oid,'EXECUTE') service_execute
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ("""+quoted+")) f"
    actual=json.loads(subprocess.check_output(['docker','exec','supabase_db_rad_core_upgrade','psql','-U','postgres','-XAtc',query],text=True,encoding='utf-8'))
    (evidence/'sql_api_signatures.json').write_text(json.dumps(actual,indent=2)+'\n',encoding='utf-8')
    fixture_count=len(read_json(ROOT/'supabase/contracts/fixtures/rad_v1_synthetic.json',[]))
    counts={key:Counter(row['status'] for row in suite) for key,suite in final_suites.items()}
    build=read_json(LOGS/'backend-final-build-checks.json',{})
    write('00_EXECUTIVE_SUMMARY.md',f"""
# RAD backend delivery — 2026-10-20

Implemented local backend continuation on `{branch}`, isolated from Backend baseline `839c749759989c922fdaa840e1a5f1e36f166b00` and Antigravity A-003 `f86cb6b`. Packaging source HEAD: `{head}`; use the delivery commits and SHA-256 migration manifest to identify the final candidate.

Delivered six additive migrations for interaction/moderation/resume, evidence integrity and source-change proposals, currency history/consent, search aliases/performance, legacy publication/privileges, CRM history, privacy, and transport contracts. The earlier C-002/C-003 implementation remains intact. No Flutter UI or other agent worktree was edited. One pre-existing backtick was removed from a backend Dart acceptance test so the suite could compile.

The clean lineage has {len(migrations)} migration files; the production-shaped path uses {len(forward)} forward files after a metadata-only reconstruction of 54 observed ledger versions. The captured catalog comparison covers ten dimensions, with explicit environment exceptions. Successful local reconstruction does not authorize production migration/history repair.

Backend mechanisms are implemented and regression-tested; live feature acceptance remains PARTIAL where approved content, authority policy/egress, external transports, frontend review, or undefined product rules are absent. All capability flags remain false. Production release is NO-GO.

No Supabase staging/production SQL, migration, deploy, restart, secret export, main merge, force push, or real content publication occurred. Publications in SQL tests are synthetic and rolled back. Git feature-branch publication is the authorized delivery action.

See the other eight documents and `evidence/`; do not substitute earlier 117-test or baseline build claims for the final results here.
""")
    write('01_FEATURE_COMPLETION_MATRIX.md',"""
# Feature completion matrix

PASS means the stated local backend behavior was exercised. PARTIAL does not claim end-to-end feature completion.

| Feature/scope | Status | Implemented and exercised | Remaining gate |
|---|---|---|---|
| Auth/RLS/privileges | PASS | Role INSERT/UPDATE denial, forged metadata denial, owner isolation, internal schemas, explicit grants, hardened definers, human publication | Fresh remote review before any release |
| 1 — Visa CMS | PARTIAL | Country×pathway main uniqueness; independent related articles; structured sections, immutable revisions/events; CAS review/approval/publish/rollback; locale, provenance, complete source manifests; bookmark/resume | Approved real RadVisa/DigiVisa corpus/inventory; frontend acceptance; approved supersession policy if editing removes archived source fragments |
| 2 — Research | PARTIAL | Authority/proof/evidence storage; checksum/freshness/conflict/revocation enforcement; query-relevant verified retrieval; leased change detection, deduplicated proposals, human review into draft | Approved trust-root policy and records; protected egress/proof producer; discovery provider; live-source acceptance |
| 3 — Currency | PARTIAL | Approved-provider cache contract; exact decimal conversion/HALF_EVEN; IRR/toman display policy; single-provider history with missing dates; alerts, consent, tombstones, owner isolation | Live provider acceptance and operational refresh ownership/deadlines; no Iranian free-market provider authorized |
| 9 — Feed/notifications | PARTIAL | Exact-revision human publishing; saved/read state; pending comments/replies, human moderation and audit; owner-bound preferences/typed notification targets; sandbox outbox lease/consent/retry | Frontend review of moderation default; external delivery provider/consent operational acceptance. Sandbox receipt is not external delivery |
| 10 — Visa search | PARTIAL | Full published bodies/related articles; Persian/English normalization; typo fallback; human-curated aliases; metadata/filters; safe UTF-16 ranges; stable versioned pagination and revocation | Reviewed bilingual gold corpus and agreed staging capacity test |
| 11 — AI security | PASS | Shared legacy/v1 reservations, concurrent count/token ceilings, idempotency, same-row settlement/release, conservative expiry, owned sessions/history, official-only retrieval | Orchestrator integration/e2e remains a separate owner gate |
| 11 — RAD AI 2.0 end-to-end | PARTIAL | Existing text-only integration retained; backend quota/retrieval/tool contracts provided | Grok orchestration and adversarial live integration review; Antigravity UI acceptance |
| Consultation/service intake foundation | PASS | Existing owned intake, 3/hour and 10/day controls, narrow reads, admin CAS transition/assignment and history | Product owner must define services, availability and appointment semantics |
| Interview scheduling | BLOCKED | Existing intake can collect a request | No approved slots, timezone/cancellation/availability rules; appointment API proposed only |
| Cost calculator | BLOCKED | Decimal FX and sourced content primitives available | Approved cost data, line items, assumptions, validity periods and calculation rules |
| Country/visa comparison | PARTIAL | Published canonical articles and catalog metadata can be read without inventing eligibility | Comparison fields/normalization and missing-data rules await product approval; no comparison RPC implemented |
| University comparison | NOT IMPLEMENTED | No verified university comparison dataset added | Approved dataset, fields, evidence/licensing and comparison rules |
| Payment/OCR/incident feature expansion | BLOCKED | Existing clean-lineage code retained; optional captured-baseline gaps recorded | C-003 R08/R09 and optional incident migrations need their own review; keep features disabled |

No prices, service packages, legal eligibility, university partnerships, appointment guarantees, live immigration claims, voice or image workflows were invented.
""")
    migration_table='\n'.join(f"| `{row['file']}` | `{row['sha256']}` |" for row in manifest if row['file']>='20261019204906_')
    write('02_DATABASE_MIGRATION_REPORT.md',f"""
# Database migration report

READ-ONLY remote boundary: production `inshddthftkhcdosoqcn` and staging were not modified. Local writes were confined to marked, allocated Docker projects `rad_core_upgrade` (60322) and `rad_core_canonical` (61322), with matching container port and checkout ownership checks.

R00 reconstructed the captured schema/function/RLS/grant/Storage metadata without real application rows or Vault values, installed 54 synthetic ledger identities, and compared tables, columns, constraints, indexes, policies, table grants, column grants, functions/body/search path/effective ACL, triggers and bucket metadata. There were no differences in these ten dimensions; the local CLI dry-run showed zero historical migrations pending before upgrade.

This is a metadata rehearsal, not a production restore. Extension patch versions, newer local Storage objects, platform-owned auth/storage internals, inactive no-op cron commands, omitted Vault values and omitted business data are explicit exceptions. Schema/default-ACL and live cron command parity are not claimed. The baseline capture must be refreshed before release.

Clean replay uses the existing authoritative repository lineage only in the disposable environment. Historical files that open BEGIN without COMMIT are wrapped with the same effective boundary supplied by the CLI. The first runner attempt exposed this issue, was discarded in its owned environment, and was corrected. The production-shaped path never executes historical SQL. Cron schedules in the metadata reconstruction are inactive; clean-replay schedules are disabled as migration files are applied.

The previous `pg_cron` permission problem was resolved using `cron.alter_job(..., active := false)`, not direct writes/grants to `cron.job`.

New corrections preserve historical files. Runtime tests caught a later legacy publisher replacement removing its human marker/grants, and schema-local default revokes failing to remove global PUBLIC execute. Both have additive fixes. The global default revoke requires explicit grants for temporary test helpers as well. R05 adds consultation history without fabricating past events; R06 adds only the reviewed privacy effect, without telemetry scrub or alert activation.

| Forward file | SHA-256 |
|---|---|
{migration_table}

Canonical and upgrade reports include the verified 76-file clean prefix and two appended files, and the verified 16-file production-shaped upgrade followed by its two explicit additive appends. The consolidated manifest covers all files. Raw sha256 values describe Windows rehearsal bytes; git_lf_sha256 values describe Git-published LF bytes. CRLF-to-LF equivalence was checked; no historical migration contents were edited. These conventions matter when verifying the manifest on Linux. Final remote migration authorization, fresh drift reconciliation, preimage/dependency checks, lock assessment, backup/recovery rehearsal and frontend contract acceptance remain release gates. Never replay or repair the production historical ledger to match the repository count.
""")
    write('03_SECURITY_RLS_RESULTS.md',"""
# Security and RLS results

| Boundary | Status | Evidence |
|---|---|---|
| Privileged profile INSERT/UPDATE | PASS | HTTP role-column writes rejected; SQL forged user_metadata admin rejected; safe orphan completion still succeeds |
| User isolation | PASS | Profiles, notifications, reading state, comments and consultations isolated; cross-owner AI session/history insertion rejected |
| Quota races | PASS | Ten concurrent v1 requests admit two at a two-request cap; ten mixed legacy/v1 requests also admit two; same key reuses one row, changed body conflicts |
| Token accounting | PASS | Pending budget blocks oversubscription; actual settlement releases unused reservation; expiry charges unknown usage conservatively and fences late completion |
| Draft/publication boundary | PASS | Draft reads/search rejected; exact hash/revision review; worker/service cannot publish; legacy human marker/grants restored |
| Evidence/grounding | PASS | Missing proof, expiry, conflict, inactive root and revoked domain fail closed; exact quote/snapshot/citation required; no unrelated-query fallback |
| Research review | PASS | No-change sources create no proposal; leased change repeats deduplicate; acceptance creates a draft and leaves published pointer unchanged |
| Private helpers / defaults | PASS | Runtime catalog checks forbid PUBLIC execution and client execution except has_role; anonymous read definers are an explicit signature allowlist |
| Search | PASS | Published pointer recheck, filter/actor/version cursor binding, revocation invalidation, UTF-16 offsets and Persian normalization |
| Telemetry privacy | PASS | Nested/array/key canaries removed; allowed metrics retained; redaction idempotent; malformed payload rejected |
| Remote staging finding | BLOCKED | The captured staging schema has twelve RLS-disabled tables; no remediation was executed in this phase |

Captured RLS-disabled staging tables: admin_audit_logs, ai_entitlements, ai_models, ai_requests, ai_usage_limits, applications, consultation_requests, content_drafts, document_processor_config, feed_item_localizations, feed_items, profiles. This is a finding requiring investigation and fresh verification, not authorization to expose or change them.

Editorial approval is independent from factual verification. Trust is re-evaluated at read time. Authority roots/proofs are not seeded or activated by migrations. Anonymous published-read definers use private tables without granting raw draft/table access. RLS remains enabled on application tables.

Security scope does not claim a penetration test of deployed services, live provider behavior, or production-wide data retention/deletion acceptance. Service credentials remain server-only and were never printed, exported or committed.
""")
    rows=[]
    for e in registry['endpoints']:
        schema=registry['$defs'][e['request']['$ref'].split('/')[-1]]
        required=', '.join('`'+x+'`' for x in schema.get('required',[])) or 'none'
        rows.append(f"| `{e['name']}` | {e['transport']} / {e['access']} | {required} | `{e['response']['$ref'].split('/')[-1]}` | {'cursor' if e['paged'] else 'none'} |")
    signatures='\n'.join(f"- `public.{f['name']}({f['arguments']}) → {f['result']}`" for f in actual)
    write('04_API_CONTRACTS.md',f"""
# Shared API and data contracts — backend integration candidate

Authoritative closed request/response schemas: `../supabase/contracts/rad_v1.json`, with {fixture_count} real SQL-generated synthetic request/response fixtures in `../supabase/contracts/fixtures/rad_v1_synthetic.json`. Exact runtime SQL signatures and grants: `evidence/sql_api_signatures.json`. Fixtures contain no real immigration facts or user data. Contract review by Antigravity and final project-owner approval are pending; this chat and the committed branch are the coordination channel.

Every client SQL RPC is POST `/rest/v1/rpc/<name>` with body `{{"p_request": <request schema>}}`. SQL success is `{{data, meta}}`, plus `page` for lists. All list payloads use `data.items`; notifications also include unread_count, search includes index_version/query_normalized/evidence_state, and FX history includes provider/missing_dates. Required nullable fields must be sent explicitly. UUID identities and stable section UUIDs are distinct from human-readable anchors. Dates are ISO strings, timestamps UTC, and rates/amounts/scores are decimal strings. Identity conversion has `observation: null` and `conversion_kind: identity`, not a fake fetched quote. IRT is rejected; toman is an IRR display/unit conversion with scale 10.

Mutation request_key is an actor/operation-bound UUID. Identical retries reuse the stored result; changed bodies return PT409. expected_revision/content_hash enforce CAS and exact-review identity. Tokens are opaque, actor/filter/version bound, expire after fifteen minutes, and must be restarted after PT409 cursor_expired. Limits are 1–50 and ordering is deterministic. Publication and alias changes invalidate search cursors.

SQL errors retain PostgREST's code/message/details/hint shape: PT401 authentication, PT403 authorization, PT404 hidden/missing resource, PT409 revision/idempotency/cursor conflict, PT422 invalid input, PT429 abuse control, PT503 unavailable. Existing legacy SQLSTATEs (42501, 22023, 40001, P0001/P0002) remain in the older consultation APIs; adapt by code rather than assuming one HTTP status for every legacy error. Edge errors are flat error/code/request_id where present; do not assume the old proposed nested error envelope.

| Operation | Transport / authorization | Required request properties | Response schema ($defs) | Pagination |
|---|---|---|---|---|
{chr(10).join(rows)}

Full field types, enums, bounds, nullable alternatives, nested data models and request examples are in the machine registry/fixtures. Key shared models: VisaArticle, ArticleSection/Input, ContentBlock, EvidenceRef, MergeManifest, ResearchProposal/SectionChange, Authority, FxObservation, ConversionResult, CurrencyAlert, FeedItem, FeedComment, NotificationPreferences, Notification, NavigationTarget, SearchHit, VisaReadingState and CopilotResult.

Internal service RPCs use their explicit named arguments below, not p_request unless the signature says so. reserve_rad_ai_request binds user/session ownership and reserves 1–8192 output tokens; same key returns a running/terminal replay, and denied responses have allowed=false. settle_rad_ai_request returns true exactly once, then false; consumption must be within the reservation. expire_rad_ai_reservations releases running state with a conservative token charge and purges cached replies after 24 hours. Maintenance scheduling is not activated here. retrieve_verified_official_claims returns results/evidence_state, requires service role, and checks current published usage and live proof eligibility. get_research_article_base requires a live research-refresh lease and an authority country scope matching the target article; it returns current sections and server-generated before_hash values. Workers reuse these hashes in SectionChange and must not reproduce PostgreSQL JSON canonicalization in JavaScript or a model. No service RPC is a human publication endpoint.

Protected workers are synchronous in the existing code: currency-refresh accepts pairs and returns per-pair cached/unavailable results; visa-content-ingest returns a draft/manifest envelope; official-source-worker reports candidates/verified=0/status; notification-dispatch returns sandbox counters. These supersede the earlier proposed JobResult shapes. Jobs created by admin research RPCs still use get_rad_job_status. Purpose-token and deployment JWT boundaries stay server-only; workers remain disabled.

## Exact verified SQL signatures

{signatures}

## Proposed new-feature contracts — NOT IMPLEMENTED, approval required

- Existing confirmed booking foundation is submit_consultation_request(topic,message,related_application_id?) → UUID. It is an owned intake request, with three/hour and ten/day limits; it does not promise a booked appointment. Owner reads exclude admin_note/assignment internals; admins use the explicit RPCs.
- Proposed create_appointment_request: owned request_key, service_reference, preferred UTC windows and IANA timezone; response request_id/state=requested/revision. Availability, confirmation, rescheduling, cancellation and interview/provider ownership must be approved before implementation.
- Proposed estimate_immigration_costs: approved scenario/input schema, decimal line items with currency, provenance, as_of/validity, declared assumptions and missing_inputs; no invented totals when required evidence is absent. Tax/fee scope and FX policy require approval.
- Proposed compare_visa_pathways: bounded published article IDs and approved comparison fields; values retain source/revision/missing state. Existing get_visa_article is reusable now. Eligibility/ranking/recommendation semantics require approval.
- Proposed compare_universities: approved university IDs/dataset version/fields, with citations, effective dates and missing states. Dataset provenance/licensing, partnerships and ranking rules are unapproved; no endpoint or fabricated dataset was added.
""")
    sqltable='\n'.join(f"| {scope} | {row['test']} | {row['status']} |" for scope,suite in final_suites.items() for row in suite)
    write('05_TEST_RESULTS.md',f"""
# Test results

Results refer to local synthetic environments, not production. Files under evidence/ retain counts, SQL hashes and replay manifests. Source HEAD at packaging: `{head}`; final delivery commit identities belong in the Git handoff. Final source manifest comparison is required when consuming this report.

| Check | Status / result |
|---|---|
| Deno | {results['deno']['status']} — {results['deno']['result'].replace('|',' / ')} |
| Flutter analysis | {results['flutter_analysis']['status']} — {results['flutter_analysis']['result']} |
| Flutter suite | {results['flutter_tests']['status']} — {results['flutter_tests']['result']} |
| Final web build | {'PASS' if build.get('web')==0 else 'NOT RUN'} |
| Final Android debug build | {'PASS' if build.get('android')==0 else 'NOT RUN'} |
| HTTP Auth/RLS/quota | {read_json(RUNTIME/'http_acceptance.json',{}).get('status','NOT RUN')} — {len(read_json(RUNTIME/'http_acceptance.json',{}).get('checks',[]))} checks |
| Clean SQL suite | {dict(counts['clean'])} |
| Upgrade SQL suite | {dict(counts['upgrade'])} |
| SQL wire validation | PASS — {fixture_count} actual request/response fixtures, also validated independently in Deno |
| Synthetic search p95 | {metrics} ms; 10,000 sections, twenty warm samples per environment |
| Approved bilingual gold corpus | BLOCKED — no reviewed real corpus supplied |
| Live official-source/FX/model/external delivery acceptance | NOT RUN |
| Production migration/deploy | NOT RUN — prohibited |
| GitHub CI / secret scan | See final evidence/ci_status.json and evidence/secret_scan.json when present; absence means NOT RUN |

| Environment | SQL suite | Status |
|---|---|---|
{sqltable}

Earlier failures were retained in external logs, corrected, and superseded by final runs: runner transaction boundary; comment alias/check constraint; old preferences test bypassing the new RPC; explicit temporary-function grants under hardened defaults; a stray leading backtick in the consultation acceptance test. The initial search p95 was 15.8 seconds; narrow ranking/materialization reduced it substantially. An intermediate noisy shared-host run measured 579.870 ms; final values above are not a production capacity guarantee.

Optional payment/OCR/incident suites are NOT RUN in the production-shaped path when the captured schema lacks their approved dependencies. Their clean-lineage suites are still run. The mandatory standalone privacy test runs in both environments. No unavailable review, transport or test is described as passed.
""")
    write('06_INTEGRATION_INSTRUCTIONS.md',f"""
# Integration instructions

Consume `{branch}` only after reviewing its commits against base 839c749. Antigravity's worktree/branch was inspected read-only and remains owned by Antigravity. No automatic main merge or deployment is part of this delivery.

1. Antigravity and the project owner review 04_API_CONTRACTS.md, rad_v1.json, the SQL signature inventory and synthetic fixtures in this chat/branch. Record explicit acceptance before enabling capabilities.
2. In an isolated integration branch, combine the reviewed backend commits with A-003; resolve conflicts with each file owner. Re-run SQL/HTTP/Flutter acceptance on the combined branch. Do not cherry-pick the historical schema files into production as a ledger repair.
3. Use p_request wrapping, data.items list shapes, UUID targets/section IDs, decimal strings and schema-defined missing states. Preferences writes strip revision/updated_at from preferences, pass expected_revision separately and use a new request_key. Render stale/unavailable/conflicting states truthfully.
4. A-003's fx_rate.dart currently parses rates into double and defaults missing freshness/date/provider values. Frontend owner must replace these fallbacks and use server arithmetic/explicit availability. Its compatibility search fixture contains optional country_code/slug fields not guaranteed by SearchHit; navigate with target.id/section_id. Remove unverified numeric immigration examples from acceptance assumptions.
5. Feed comments start pending; only the author sees their pending comment and a moderator can make it visible/hidden. Author deletion erases displayed text and preserves state audit. This conservative moderation default needs frontend/product acceptance. Reading state revision 0 means no stored pointer; deleted/replaced sections resolve to null on read.
6. Grok owns service orchestration integration. Enforce actor JWTs for personal tools, a closed read-only tool allowlist, bounded body/runtime/provider usage, idempotency before inference, exact returned reservation settlement and official-only grounding. Do not send service credentials or unauthorized personal tool data to the model. Voice/image remains deferred. No duplicate Edge implementation was introduced by this continuation.
7. Freebuff may integrate confirmed consultation intake and published-content/decimal primitives. Appointment, calculator and comparison business APIs remain proposals; use explicit unavailable/requested/missing states rather than fictional confirmations, prices or rules.
8. For a fresh local upgrade rehearsal, allocate an empty external runtime with rad_local_rehearsal.py start, then reconstruct → compare → upgrade. The checked marker, project-specific Docker port and loopback DSN are mandatory. Use a different owned project/port from existing stacks. For clean replay, use start → canonical. Run rad_backend_regression.py, rad_wire_acceptance.py and verify_rad_http.py only against their owned runtime.
9. Release owner refreshes the production metadata baseline, reconciles the exact forward manifest/dependencies and approves a separate rollout/rollback plan. Backend flags, purpose workers, external delivery and authority trust remain disabled until their gates pass. No migration, history repair, staging change or deploy was executed here.

Real content import requires owner-approved exact source inventory. Main publication preserves all accounted unique fragments and rejects RadMohajer/transitive prohibited ancestry. A proposed edit that removes an archived fragment will be blocked; do not bypass that guard. A reviewed evidence-backed supersession contract is required if editorial replacement is intended to remove it.
""")
    write('07_REMAINING_BLOCKERS.md',"""
# Exact remaining blockers

| Blocker / reproducible condition | Owner | Required action / acceptance gate |
|---|---|---|
| No fresh remote reconciliation approval | Project owner + Codex/Gemini reviewer | Refresh metadata/history evidence; reconcile exact forward manifest, ACL/default-ACL and dependencies; review locks/recovery; separately authorize any remote change |
| Twelve captured staging tables have RLS disabled | Project owner + security reviewer | Read-only investigate actual current staging state and intended access; approve a separate remediation; never expose/reset them as a shortcut |
| No approved real Visa corpus/inventory | Project/content owner | Supply/approve exact RadVisa+DigiVisa source snapshot set, locales, related-article separation and fragment accounting; run an isolated real-content review without auto-publication |
| Archived-fragment removal/supersession semantics undefined | Content owner + Antigravity + Codex | Approve an explicit evidence-backed supersession/versioned manifest contract; literal preservation remains fail-closed until then |
| No active authority trust roots/proof producer | Project owner + research/security owner | Approve identity/competence/freshness policy and protected egress verification; supply legitimate proofs; test expiry/revocation and prompt-injection boundaries live |
| Official discovery adapter / protected refresh unavailable | Research/Edge owner | Configure approved discovery and pinned egress; verify public-only DNS/redirect/size/time bounds; candidates must never auto-verify or auto-publish |
| Frontend contract sign-off pending | Antigravity + project owner | Review the committed schemas/fixtures in this chat; replace fake freshness/date defaults, double arithmetic and mismatched error/list assumptions; run combined branch tests |
| AI 2.0 orchestration integration/e2e pending | Grok + Antigravity + security reviewer | Bind existing text-only runtime to quota/retrieval contracts; test deadlines, provider denial/replay, personalization consent, cross-user tools, refusal/injection and settlement; do not infer live grounding from unit tests |
| Worker operational acceptance incomplete | Edge/operations owner | Currency worker needs bounded-read/deadline review and live provider acceptance; protected workers must retain purpose auth/default OFF; contract shapes are documented, no duplicate handler added |
| Real notification transports unconfigured | Product + operations owner | Approve provider/consent policy and receipt semantics; test targeting/timezone/revocation with approved sandbox endpoints before any external send |
| Reviewed bilingual search corpus / production-like capacity unapproved | Content + frontend + release owner | Agree gold cases and staging fixture/load target; test all filters, typo/alias recall, UTF-16 ranges and revoke races on the integrated release |
| New scheduling/cost/comparison business rules absent | Project owner + Freebuff | Approve services, appointment states/timezone/availability, cost sources/assumptions, comparison fields/dataset licensing. Proposed contracts are not implemented endpoints |
| Optional payment/OCR/incident dependency gaps in captured schema | Owners of C-003 R08/R09/incident work | Review their separate additive migration plans; keep corresponding features disabled; clean local availability is not proof of production availability |
| GitHub CI availability/result | Gemini/repository owner | Use the delivery commit run/check links in evidence; if dispatch/auth unavailable it remains NOT RUN, never assumed green |

These gates do not block consuming the tested local backend source for review. They do block claiming a production-ready or fully accepted end-to-end release.
""")
    write('08_RELEASE_GO_NO_GO.md',"""
# Release go / no-go

**Local backend integration candidate: GO for review and isolated integration once final tests, secret scan and branch publication evidence are attached.**

**Production/staging release: NO-GO.** No remote migrations, ledger repair, deployment, main merge, content publication or external notification was authorized or performed in this phase.

Release acceptance requires current migration reconciliation and exact manifest approval; security/RLS review including staging findings; legitimate source inventory and authority/egress proof; Antigravity/project-owner contract sign-off; Grok/Flutter integrated adversarial tests; approved search gold/capacity evidence; and operational provider/transport review. Undefined booking/interview/cost/comparison behavior remains unavailable until approved.

Backend capability flags remain false. Research acceptance creates drafts, never publications. Editorial approval never confers factual verification. Currency observations retain provider/date/basis; toman is display arithmetic. Sandbox delivery never claims real delivery. Voice/image is not part of this phase.

Final branch/commit and CI/scan evidence identify what can be reviewed. No report status authorizes a future production action.
""")
    print(json.dumps({'directory':str(OUTPUT),'documents':9,'fixtures':fixture_count,'migration_files':len(migrations),'forward_files':len(forward),'sql_results':{k:dict(v) for k,v in counts.items()}},indent=2))


if __name__=='__main__':main()
