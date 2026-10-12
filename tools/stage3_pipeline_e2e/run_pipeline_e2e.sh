#!/usr/bin/env bash
# E2E pipeline verification on disposable PostgreSQL 16.
#
# Applies a dependency-ordered SUBSET of the REAL committed migrations
# (verbatim, except two platform-unavailable `create extension` lines in
# project10 which are stripped — pg_cron/pg_net are Supabase-only; their
# cron.schedule calls resolve to harmless local stubs and their scheduled
# bodies never run), then exercises the intended architecture:
#   source_documents -> source_snapshots -> research_findings
#     -> content_drafts(review) -> human approval -> publish RPC -> Feed
set -u
R="$(cd "$(dirname "$0")/../.." && pwd)"
M="$R/supabase/migrations"
C=rad_pipeline_e2e
DB=rad_e2e
PSQL="docker exec -i $C psql -U postgres -d $DB -t -A"
OUT="$R/tools/stage3_pipeline_e2e/E2E_RESULTS.txt"
FAILURES=0

say() { echo "$1" | tee -a "$OUT"; }
# stub: 3-arg cron.schedule overload (job_name, schedule, command) used by
# project10's scheduled research jobs
chk() { # name expected actual
  if [ "$2" = "$3" ]; then say "PASS $1=$2"
  else say "FAIL $1: expected=$2 actual=$3"; FAILURES=$((FAILURES + 1)); fi
}
q() { $PSQL -c "$1" 2>&1 | tail -1; }
# run SQL expecting an error code; captures the actual SQLSTATE
# (VERBOSITY verbose makes psql print `ERROR:  [42501] message`)
expect_err() { # name expected_sqlstate sql
  local out
  out=$(docker exec -i $C psql -U postgres -d $DB -q -v ON_ERROR_STOP=1 \
    -c "\\set VERBOSITY verbose" -c "$3" 2>&1 >/dev/null)
  local code
  # verbose format: "ERROR:  42501: message"
  code=$(echo "$out" | grep -oE 'ERROR: +[0-9A-Z]{5}' | head -1 | sed -E 's/ERROR: +//')
  chk "$1" "$2" "${code:-none}"
}

: > "$OUT"
say "=== PIPELINE E2E ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="

# ---------- environment ----------
docker rm -f $C >/dev/null 2>&1
docker run -d --name $C -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=$DB \
  postgres:16-alpine >/dev/null || exit 9
for i in $(seq 1 60); do
  docker exec $C pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done
docker exec $C pg_isready -U postgres >/dev/null 2>&1 || { say "FAIL postgres not ready"; exit 9; }

say "--- prelude (platform stubs) ---"
docker exec -i $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 \
  < "$R/tools/stage3_pipeline_e2e/00_prelude.sql" >>"$OUT" 2>&1 \
  && say "PRELUDE OK" || { say "FAIL prelude"; tail -5 "$OUT"; exit 9; }

# ---------- real migrations (dependency order, verbatim + documented strip) ----------
apply() { # file [strip]
  local f="$M/$1"
  say "--- migration $1 ---"
  # some migration files open `begin;` but never `commit;` (the Supabase CLI
  # commits them); psql would roll back on exit, so append an explicit commit
  if [ "${2:-}" = "strip-extensions" ]; then
    { sed '/^create extension if not exists pg_cron/d; /^create extension if not exists pg_net/d' "$f"; echo 'commit;'; } \
      | docker exec -i $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 >>"$OUT" 2>&1
  else
    { cat "$f"; echo 'commit;'; } \
      | docker exec -i $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 >>"$OUT" 2>&1
  fi
  if [ $? -eq 0 ]; then say "OK $1"
  else say "FAIL $1"; grep -m2 -E "ERROR" "$OUT" | tail -2; exit 9; fi
}

apply 20261001191421_initial_rad_core_schema.sql
apply 20261003210302_project09_visa_catalog.sql
apply 20261003211635_project10_knowledge_research.sql strip-extensions
apply 20261003212339_project10_security_hardening.sql
apply 20261003213219_project11_ai_orchestration.sql
apply 20261003214031_project12_document_intelligence.sql
apply 20261003222909_project14_feed_notifications.sql
apply 20261003223717_project15_observability.sql
apply 20261003235000_ai_base_url_ssrf_hardening.sql
apply 20261004190000_fix_profile_update_rls_recursion.sql
apply 20261004203000_client_delivery_ai_scopes.sql
apply 20261005102000_stage1_ai_research_completion.sql
apply 20261005120000_stage2_review_feed_publish.sql
apply 20261006132931_stage5_research_review_candidate_backfill.sql
apply 20261006180000_fix_profile_update_with_check_role_escalation.sql
apply 20261007080000_ai_dynamic_routing_architecture.sql
apply 20261007080001_ai_credential_failure_routing.sql
apply 20261007080002_research_atomic_review_candidate.sql
apply 20261007180000_stage2_knowledge_completion.sql
apply 20261007180001_stage2_knowledge_promote.sql
apply 20261007180002_stage2_knowledge_retrieve_conflict.sql
apply 20261007210000_stage4_user_ai_quota_grounding.sql
apply 20261007212000_stage4_limit_ai_runtime_chain.sql
apply 20261007220000_stage5_visa_editorial_summaries.sql
apply 20261007230000_stage6_entitlement_access_decision.sql
apply 20261008010000_stage7_ops_consultation_app_status.sql
apply 20261008020000_stage9_security_grant_hardening.sql
apply 20261010010000_stage1_p0_security_completion.sql

# ---------- actors ----------
say "--- actors ---"
docker exec -i $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 >>"$OUT" 2>&1 <<'EOF'
insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111','svc@rad.local'),
  ('22222222-2222-4222-8222-222222222222','editor@rad.local'),
  ('33333333-3333-4333-8333-333333333333','admin@rad.local');
insert into public.profiles (id, role) values
  ('11111111-1111-4111-8111-111111111111','user'),
  ('22222222-2222-4222-8222-222222222222','user'),
  ('33333333-3333-4333-8333-333333333333','admin');
EOF
say "actors OK"

# helper: run a statement as a given role with JWT claims set
as() { # role sub claims_extra sql
  docker exec -i $C psql -U postgres -d $DB -q -v ON_ERROR_STOP=1 \
    -c "set role $1;" \
    -c "select set_config('request.jwt.claim.sub','$2',false);" \
    -c "select set_config('request.jwt.claims','$3',false);" \
    -c "$4" >>"$OUT" 2>&1
}
SVC='{"role":"service_role","sub":"11111111-1111-4111-8111-111111111111"}'
EDI='{"role":"authenticated","sub":"22222222-2222-4222-8222-222222222222"}'
ADM='{"role":"authenticated","sub":"33333333-3333-4333-8333-333333333333"}'
ANON='{"role":"anon"}'

# seed a source document + research job (as service_role via direct SQL is
# fine for fixtures; the RPCs are what we test)
docker exec -i $C psql -q -U postgres -d $DB -v ON_ERROR_STOP=1 >>"$OUT" 2>&1 <<'EOF'
insert into public.source_documents (canonical_url, source_authority, title, language_code)
values ('https://radmohajer.ir/fa/e2e-test', 'rad_official', 'E2E Test Page', 'fa');
insert into public.research_jobs (job_type, trigger_type, idempotency_key)
values ('targeted_research','manual','e2e-job-1');
EOF

DOC=$(q "select id from public.source_documents where canonical_url='https://radmohajer.ir/fa/e2e-test'")
JOB=$(q "select id from public.research_jobs where idempotency_key='e2e-job-1'")
say "doc=$DOC job=$JOB"

# ---------- S1: service_role ingest (new) ----------
say "--- S1: ingest snapshot (service_role) ---"
as service_role "11111111-1111-4111-8111-111111111111" "$SVC" \
  "select public.ingest_research_snapshot('$JOB','$DOC','hash-aaa','E2E normalized text one',200,'{}'::jsonb);" \
  && say "S1 ingest OK" || say "FAIL S1 ingest"
chk s1_snapshots 1 "$(q 'select count(*) from public.source_snapshots')"
chk s1_findings 1 "$(q 'select count(*) from public.research_findings')"
chk s1_finding_type_new "new" "$(q "select finding_type from public.research_findings limit 1")"
chk s1_drafts_review 1 "$(q "select count(*) from public.content_drafts where status='review'")"
chk s1_doc_hash_updated "hash-aaa" "$(q 'select last_content_hash from public.source_documents limit 1')"

# ---------- S2: duplicate ingest (same hash) is idempotent ----------
say "--- S2: duplicate ingest (same hash) ---"
as service_role "11111111-1111-4111-8111-111111111111" "$SVC" \
  "select public.ingest_research_snapshot('$JOB','$DOC','hash-aaa','E2E normalized text one',200,'{}'::jsonb);" \
  && say "S2 duplicate OK (returned without insert)" || say "FAIL S2"
chk s2_snapshots 1 "$(q 'select count(*) from public.source_snapshots')"
chk s2_findings 1 "$(q 'select count(*) from public.research_findings')"
chk s2_drafts 1 "$(q 'select count(*) from public.content_drafts')"

# ---------- S3: retry after ambiguous result (identical args again) ----------
say "--- S3: retry idempotency ---"
as service_role "11111111-1111-4111-8111-111111111111" "$SVC" \
  "select public.ingest_research_snapshot('$JOB','$DOC','hash-aaa','E2E normalized text one',200,'{}'::jsonb);" \
  && say "S3 retry OK" || say "FAIL S3"
chk s3_snapshots 1 "$(q 'select count(*) from public.source_snapshots')"
chk s3_findings 1 "$(q 'select count(*) from public.research_findings')"

# ---------- S4: changed content -> 'changed' finding + 2nd draft ----------
say "--- S4: changed content ---"
as service_role "11111111-1111-4111-8111-111111111111" "$SVC" \
  "select public.ingest_research_snapshot('$JOB','$DOC','hash-bbb','E2E normalized text two v2',200,'{}'::jsonb);" \
  && say "S4 changed OK" || say "FAIL S4"
chk s4_snapshots 2 "$(q 'select count(*) from public.source_snapshots')"
chk s4_finding_changed "changed" "$(q "select finding_type from public.research_findings order by created_at desc limit 1")"
chk s4_drafts 2 "$(q 'select count(*) from public.content_drafts')"

# ---------- S5: invalid evidence rejected, zero rows ----------
# (run as service_role so the permission gate passes and the *validation*
# branch is what raises)
say "--- S5: invalid evidence ---"
expect_err s5_empty_text 22023 \
  "select set_config('request.jwt.claims','$SVC',false); select public.ingest_research_snapshot('$JOB','$DOC','hash-ccc','   ',200,'{}'::jsonb);"
expect_err s5_bad_status 22023 \
  "select set_config('request.jwt.claims','$SVC',false); select public.ingest_research_snapshot('$JOB','$DOC','hash-ccc','text',500,'{}'::jsonb);"
chk s5_snapshots_still 2 "$(q 'select count(*) from public.source_snapshots')"

# ---------- S6: anon cannot ingest ----------
say "--- S6: anon ingest forbidden ---"
expect_err s6_anon_ingest 42501 \
  "set role anon; select public.ingest_research_snapshot('$JOB','$DOC','hash-ddd','anon text',200,'{}'::jsonb);"
chk s6_snapshots_still 2 "$(q 'select count(*) from public.source_snapshots')"

# ---------- S7: direct Feed writes blocked for ALL roles ----------
say "--- S7: direct Feed writes blocked ---"
expect_err s7_anon_feed 42501 \
  "set role anon; insert into public.feed_items(slug,category) values ('e2e-slug-1','update');"
expect_err s7_auth_feed 42501 \
  "set role authenticated; select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false); insert into public.feed_items(slug,category) values ('e2e-slug-2','update');"
expect_err s7_svc_feed 42501 \
  "set role service_role; insert into public.feed_items(slug,category) values ('e2e-slug-3','update');"
expect_err s7_svc_localization 42501 \
  "set role service_role; insert into public.feed_item_localizations(feed_item_id,locale,title,summary,body) values (gen_random_uuid(),'fa','x','y','z');"
chk s7_feed_count 0 "$(q 'select count(*) from public.feed_items')"

# ---------- S8: non-admin cannot publish ----------
say "--- S8: non-admin publish forbidden ---"
DRAFT_REVIEW=$(q "select id from public.content_drafts where status='review' order by created_at limit 1")
expect_err s8_editor_publish 42501 \
  "set role authenticated; select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false); select set_config('request.jwt.claims','$EDI',false); select public.publish_content_draft('$DRAFT_REVIEW');"

# ---------- S9: admin publish requires explicit approval ----------
say "--- S9: unapproved publish refused ---"
expect_err s9_unapproved 22023 \
  "set role authenticated; select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false); select set_config('request.jwt.claims','$ADM',false); select public.publish_content_draft('$DRAFT_REVIEW');"

# ---------- S10: approve -> publish -> feed; idempotent re-publish ----------
say "--- S10: approve + publish + idempotent re-publish ---"
as authenticated "33333333-3333-4333-8333-333333333333" "$ADM" \
  "select public.set_content_draft_status('$DRAFT_REVIEW','approved');" \
  && say "S10 approve OK" || say "FAIL S10 approve"
as authenticated "33333333-3333-4333-8333-333333333333" "$ADM" \
  "select public.publish_content_draft('$DRAFT_REVIEW','update','e2e-draft-one');" \
  && say "S10 publish OK" || say "FAIL S10 publish"
chk s10_feed_items 1 "$(q 'select count(*) from public.feed_items')"
chk s10_localizations 1 "$(q 'select count(*) from public.feed_item_localizations')"
chk s10_draft_published "published" "$(q "select status from public.content_drafts where id='$DRAFT_REVIEW'")"
chk s10_audit_row 1 "$(q "select count(*) from public.admin_audit_logs where action='publish' and resource_type='content_draft'")"
FEED_ID=$(q 'select id from public.feed_items limit 1')
as authenticated "33333333-3333-4333-8333-333333333333" "$ADM" \
  "select public.publish_content_draft('$DRAFT_REVIEW');" && say "S10 re-publish OK" || say "FAIL S10 re-publish"
chk s10_feed_still_1 1 "$(q 'select count(*) from public.feed_items')"
chk s10_same_feed_id "$FEED_ID" "$(q 'select id from public.feed_items limit 1')"

# ---------- S11: interrupted ingest transaction leaves zero partial rows ----------
say "--- S11: interrupted ingest transaction ---"
docker exec -i $C psql -U postgres -d $DB -q >>"$OUT" 2>&1 <<EOF
begin;
set local role service_role;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','$SVC',true);
select public.ingest_research_snapshot('$JOB','$DOC','hash-eee','interrupted text',200,'{}'::jsonb);
rollback;
EOF
chk s11_snapshots_still 2 "$(q 'select count(*) from public.source_snapshots')"
chk s11_drafts_still 2 "$(q 'select count(*) from public.content_drafts')"
as service_role "11111111-1111-4111-8111-111111111111" "$SVC" \
  "select public.ingest_research_snapshot('$JOB','$DOC','hash-eee','interrupted text',200,'{}'::jsonb);" \
  && say "S11 retry-after-interrupt OK" || say "FAIL S11 retry"
chk s11_after_retry_snapshots 3 "$(q 'select count(*) from public.source_snapshots')"
chk s11_after_retry_drafts 3 "$(q 'select count(*) from public.content_drafts')"

# ---------- S12: rejected draft cannot be published ----------
say "--- S12: rejected draft cannot publish ---"
DRAFT2=$(q "select id from public.content_drafts where status='review' order by created_at limit 1")
as authenticated "33333333-3333-4333-8333-333333333333" "$ADM" \
  "select public.set_content_draft_status('$DRAFT2','rejected');" && say "S12 reject OK" || say "FAIL S12 reject"
expect_err s12_rejected_publish 22023 \
  "set role authenticated; select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false); select set_config('request.jwt.claims','$ADM',false); select public.publish_content_draft('$DRAFT2');"
chk s12_feed_still_1 1 "$(q 'select count(*) from public.feed_items')"

say ""
say "=== PIPELINE E2E SUMMARY: $FAILURES failures ==="
docker rm -f $C >/dev/null 2>&1
[ "$FAILURES" -eq 0 ]
