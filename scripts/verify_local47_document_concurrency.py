#!/usr/bin/env python3
"""Actual parallel local SQL sessions; only synthetic document rows are touched."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--psql', required=True, type=Path)
    parser.add_argument('--report', required=True, type=Path)
    args = parser.parse_args()
    project = os.environ.get('RAD_LOCAL47_PROJECT', 'rad_codex_local47')
    port = int(os.environ.get('RAD_LOCAL47_PORT', '55322'))
    runtime = Path(os.environ.get('TEMP', '/tmp')) / project
    assert json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text(encoding='utf-8')) == {
        'project': project, 'source': str(ROOT), 'port': port}, 'wrong runtime owner'
    env = os.environ.copy()
    env['PGPASSWORD'] = 'postgres'
    command = [str(args.psql.resolve()), '-XqAt', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=sqlstate',
               '-h', '127.0.0.1', '-p', str(port), '-U', 'postgres', '-d', 'postgres']
    owner, document = str(uuid.uuid4()), str(uuid.uuid4())
    path = owner + '/synthetic.pdf'

    def sql(source, stale_ok=False):
        result = subprocess.run(command, input="begin;set local request.jwt.claims='{\"role\":\"service_role\"}';" + source + ';commit;',
            env=env, text=True, encoding='utf-8', capture_output=True, timeout=30)
        if result.returncode:
            if stale_ok and '40001' in result.stderr:
                return None
            raise AssertionError('synthetic document SQL failed: ' + result.stderr[-180:])
        lines = [line for line in result.stdout.splitlines() if line.strip()]
        return json.loads(lines[-1]) if lines else None

    report = {'scope': 'owned_local_document_parallel_sessions', 'production_mutations': False,
        'captured_at': datetime.now(timezone.utc).isoformat(),
        'source_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'source_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip())}
    try:
        sql(f"insert into auth.users(id,email,raw_user_meta_data) values('{owner}','{owner}@example.invalid','{{}}');"
            f"insert into public.documents(id,user_id,name,file_path) values('{document}','{owner}','Synthetic parallel fixture','{path}')")
        claim_sql = f"select public.begin_document_processing('{document}','{owner}','{path}')"
        with ThreadPoolExecutor(max_workers=8) as pool:
            claims = list(pool.map(lambda _: sql(claim_sql), range(32)))
        winners = [claim for claim in claims if claim.get('claimed') is True]
        assert len(winners) == 1, 'more than one provider claim won'
        claim = winners[0]
        assert len({row['job_id'] for row in claims}) == 1, 'simultaneous claims created separate jobs'
        assert all('lease_token' not in row for row in claims if not row['claimed']), 'busy response disclosed lease'
        extraction = json.dumps({'engine': 'synthetic', 'extracted_text': 'Synthetic parallel text', 'input_sha256': 'a'*64})
        fields = json.dumps([{'field_key': 'synthetic_field', 'field_value': 'Synthetic value'}])
        completion = f"select public.complete_document_processing('{claim['job_id']}','{claim['lease_token']}','{extraction}'::jsonb,'{fields}'::jsonb)"
        with ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: sql(completion), range(20)))
        assert sum(not row['duplicate'] for row in results) == 1, 'parallel completion persisted multiple results'
        assert len({row['extraction_id'] for row in results}) == 1
        assert sql(f"select to_json(count(*)) from public.document_fields where extraction_id='{results[0]['extraction_id']}'") == 1
        # Expired claimant cannot finish after a replacement lease is created.
        previous = sql(claim_sql)
        sql(f"update private.document_processing_leases set expires_at=now()-interval '1 second' where job_id='{previous['job_id']}'")
        replacement = sql(claim_sql)
        assert replacement['claimed'] and replacement['job_id'] != previous['job_id']
        stale = f"select public.complete_document_processing('{previous['job_id']}','{previous['lease_token']}','{extraction}'::jsonb,'[]'::jsonb)"
        assert sql(stale, stale_ok=True) is None, 'expired claimant committed after replacement'
        assert sql(f"select to_json(status) from public.document_processing_jobs where id='{replacement['job_id']}'") == 'running'
        # Race failure and completion on a fresh valid lease: either terminal state
        # is permitted, but a failed job must never contain partially stored data.
        finish = f"select public.complete_document_processing('{replacement['job_id']}','{replacement['lease_token']}','{extraction}'::jsonb,'{fields}'::jsonb)"
        fail = f"select to_json(public.fail_document_processing('{replacement['job_id']}','{replacement['lease_token']}','processing_unavailable'))"
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda n: sql(finish if n % 2 else fail, stale_ok=True), range(20)))
        state = sql(f"select json_build_object('status',j.status,'extractions',(select count(*) from public.document_extractions e where e.job_id=j.id)) from public.document_processing_jobs j where id='{replacement['job_id']}'")
        assert (state['status'], state['extractions']) in [('review_required', 1), ('failed', 0)], 'partial terminal processing state'
        # Different documents share the user cap; race them on separate sessions.
        used = sql(f"select to_json(count(*)) from public.document_processing_jobs where user_id='{owner}'")
        documents = [str(uuid.uuid4()) for _ in range(24)]
        sql('insert into public.documents(id,user_id,name,file_path) values '+','.join(
            f"('{item}','{owner}','Synthetic user-cap fixture','{owner}/{item}.pdf')" for item in documents))
        with ThreadPoolExecutor(max_workers=8) as pool:
            capped = list(pool.map(lambda item: sql(f"select public.begin_document_processing('{item}','{owner}','{owner}/{item}.pdf')"), documents))
        assert sum(row.get('claimed') is True for row in capped) == 20-used, 'parallel documents bypassed the user cap'
        assert sql(f"select to_json(count(*)) from public.document_processing_jobs where user_id='{owner}'") == 20
        report.update(status='PASS', claim_requests=32, claim_winners=1, completion_requests=20,
            persistence_winners=1, stale_claim_fenced=True, failure_completion_race_requests=20,
            final_race_state=state['status'], partial_extractions=False,
            cross_document_cap_requests=24, cross_document_claim_winners=20-used, user_hourly_cap=20)
    finally:
        sql(f"delete from auth.users where id='{owner}'")
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
