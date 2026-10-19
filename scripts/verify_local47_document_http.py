#!/usr/bin/env python3
"""Real local Auth/Storage/PostgREST/SQL with an explicitly synthetic OCR adapter.

No external provider request. Temporarily enables only this disposable stack's
synthetic processor and restores its original config/secret reference on exit.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import secrets
import shlex
import socket
import subprocess
import time
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['supabase', 'psql', 'deno', 'report']:
        parser.add_argument('--'+name, required=True, type=Path)
    args = parser.parse_args()
    project = os.environ.get('RAD_LOCAL47_PROJECT', 'rad_codex_local47')
    port = int(os.environ.get('RAD_LOCAL47_PORT', '55322'))
    runtime = Path(os.environ.get('TEMP', '/tmp'))/project
    assert json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text(encoding='utf-8')) == {
        'project':project,'source':str(ROOT),'port':port}, 'wrong runtime owner'
    status = subprocess.run([str(args.supabase.resolve()), '--workdir', str(runtime), 'status', '--output', 'env'],
        capture_output=True, text=True, encoding='utf-8', check=True)
    values = {}
    for line in status.stdout.splitlines():
        parts = shlex.split(line, comments=True)
        if parts and '=' in parts[0]:
            key, value = parts[0].split('=', 1)
            values[key] = value
    api = values['API_URL'].rstrip('/')
    assert api == f'http://127.0.0.1:{port-1}', 'refusing non-owned API'
    service, anon = values['SERVICE_ROLE_KEY'], values['ANON_KEY']
    env = os.environ.copy()
    env['PGPASSWORD'] = 'postgres'
    command = [str(args.psql.resolve()), '-XqAt', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1', '-p', str(port), '-U', 'postgres', '-d', 'postgres']

    def sql(source):
        result = subprocess.run(command, input=source, env=env, capture_output=True, text=True, encoding='utf-8', timeout=30)
        assert result.returncode == 0, 'synthetic document SQL failed'
        lines = [line for line in result.stdout.splitlines() if line.strip()]
        return json.loads(lines[-1]) if lines else None

    api_port = port-1  # captured before `port` is reused for the random harness listener
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    harness = f'http://127.0.0.1:{port}'
    test_token = secrets.token_urlsafe(48)
    process = None
    users = []
    object_path = None
    secret_id = None
    saved = sql('select to_json(c) from public.document_processor_config c where singleton;')

    def request(base, path, method='GET', payload=None, token=None, elevated=False, content_type='application/json'):
        assert base in (api, harness), 'external request prohibited'
        headers = {'Content-Type':content_type}
        if base == api:
            headers.update(apikey=service if elevated else anon, Authorization='Bearer '+(token or (service if elevated else anon)))
        else:
            headers['x-rad-local-test-token'] = test_token
            if token:
                headers['Authorization'] = 'Bearer '+token
        data = payload if isinstance(payload, bytes) else (json.dumps(payload).encode() if payload is not None else None)
        req = urllib.request.Request(base+path, data=data, headers=headers, method=method)
        try:
            response = urllib.request.urlopen(req, timeout=30)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            raw = response.read(2_000_001)
            assert len(raw) <= 2_000_000, 'oversized local response'
            return response.status, json.loads(raw) if raw else {}

    def ok(response, statuses=(200, 201)):
        assert response[0] in statuses, 'unexpected synthetic HTTP status '+str(response[0])
        return response[1]

    def create_user():
        email = uuid.uuid4().hex+'@example.invalid'
        password = secrets.token_urlsafe(32)
        user = ok(request(api, '/auth/v1/admin/users', 'POST', {'email':email,'password':password,'email_confirm':True}, elevated=True))
        users.append(user['id'])
        login = ok(request(api, '/auth/v1/token?grant_type=password', 'POST', {'email':email,'password':password}))
        return user['id'], login['access_token']

    report = {'scope':'owned_local_Deno_Auth_Storage_PostgREST_SQL', 'production_mutations':False,
        'ocr_adapter':'synthetic_in_memory_fixture', 'external_provider_calls':0,
        'captured_at':datetime.now(timezone.utc).isoformat(),
        'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'source_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip())}
    try:
        owner, access = create_user()
        other, other_access = create_user()
        document = str(uuid.uuid4())
        object_path = owner+'/'+document+'/synthetic.pdf'
        ok(request(api, '/storage/v1/object/documents/'+object_path, 'POST', b'%PDF-1.4\nSynthetic fixture only',
            token=access, content_type='application/pdf'))
        ok(request(api, '/rest/v1/documents', 'POST', {'id':document,'user_id':owner,'name':'Synthetic fixture','file_path':object_path}, token=access), (200, 201, 204))
        secret_id = sql("select to_json(vault.create_secret('"+secrets.token_urlsafe(48)+"','local47-ocr-"+uuid.uuid4().hex+"'));")
        sql("update public.document_processor_config set enabled=true,provider_slug='synthetic',endpoint_url='https://ocr-fixture.example.com/process',"
            "secret_id='"+secret_id+"',max_file_bytes=10485760,timeout_ms=30000 where singleton;")
        server_env = env.copy()
        server_env.update(SUPABASE_URL=api,**{'SUPABASE_SERVICE_ROLE_KEY':service},RAD_LOCAL47_TEST_TOKEN=test_token,RAD_LOCAL47_TEST_PORT=str(port))
        allowed = 'SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY,RAD_LOCAL47_TEST_TOKEN,RAD_LOCAL47_TEST_PORT,RAD_PAYMENT_SANDBOX_ENABLED,RAD_PAYMENT_SANDBOX_SECRET'
        process = subprocess.Popen([str(args.deno.resolve()), 'run', '--allow-env='+allowed,
            f'--allow-net=127.0.0.1:{api_port},127.0.0.1:{port}', str(ROOT/'scripts/local47_http_harness.ts')],
            env=server_env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        deadline = time.monotonic()+20
        while True:
            assert process.poll() is None, 'document test harness exited early'
            try:
                ok(request(harness, '/ocr-control'))
                break
            except urllib.error.URLError:
                assert time.monotonic()<deadline, 'document harness did not start'
                time.sleep(.1)
        assert request(harness, '/documents', 'POST', {'document_id':document})[0] == 401
        assert request(harness, '/documents', 'POST', {'document_id':document}, token=other_access)[0] == 404
        with ThreadPoolExecutor(max_workers=8) as pool:
            first = pool.submit(request, harness, '/documents', 'POST', {'document_id':document}, access)
            deadline = time.monotonic()+15
            while not ok(request(harness, '/ocr-control'))['ocr_started']:
                assert time.monotonic()<deadline, 'synthetic OCR did not start'
                time.sleep(.1)
            busy = list(pool.map(lambda _: request(harness, '/documents', 'POST', {'document_id':document}, token=access), range(12)))
            assert all(code==202 and body['status']=='running' and 'lease_token' not in body for code,body in busy), 'busy processing was not fenced'
            assert sql("select to_json(count(*)) from public.document_processing_jobs where document_id='"+document+"';") == 1
            ok(request(harness, '/ocr-control', 'POST', {}))
            completed = ok(first.result(timeout=20))
        assert completed['status']=='review_required' and completed['field_count']==1
        assert ok(request(harness, '/ocr-control'))['ocr_calls'] == 1
        fields = ok(request(api, '/rest/v1/document_fields?select=*&extraction_id=eq.'+completed['extraction_id'], token=access))
        assert len(fields)==1 and fields[0]['review_status']=='unreviewed' and fields[0]['reviewed_by'] is None
        assert ok(request(api, '/rest/v1/document_extractions?select=id&id=eq.'+completed['extraction_id'], token=other_access)) == []
        assert request(api, '/rest/v1/document_fields?id=eq.'+fields[0]['id'], 'PATCH', {'field_value':'tampered'}, token=access)[0] in (400, 401, 403)
        ok(request(api, '/rest/v1/document_fields?id=eq.'+fields[0]['id'], 'PATCH',
            {'review_status':'corrected','corrected_value':'Human fixture correction','reviewed_by':other,'reviewed_at':'2000-01-01'}, token=access), (200, 204))
        reviewed = ok(request(api, '/rest/v1/document_fields?select=review_status,corrected_value,reviewed_by&id=eq.'+fields[0]['id'], token=access))[0]
        assert reviewed['reviewed_by']==owner and reviewed['corrected_value']=='Human fixture correction'
        assert sql("select to_json(count(*)) from public.document_reviews where extraction_id='"+completed['extraction_id']+"';") == 1
        report.update(status='PASS', busy_requests=12, provider_fixture_calls=1, extraction_count=1, fields_initially_unreviewed=True,
            cross_owner_denied=True, raw_field_tampering_denied=True, human_review_identity_attributed=True, review_audit_count=1)
    finally:
        try:
            if process:
                # Release a blocked fixture on failure before stopping the server.
                try:
                    request(harness, '/ocr-control', 'POST', {})
                except Exception:
                    pass
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
        finally:
            # Restore every configuration field without interpolating SQL identifiers.
            encoded = json.dumps(saved).replace("'", "''")
            sql("update public.document_processor_config c set (provider_slug,endpoint_url,secret_id,enabled,max_file_bytes,timeout_ms,updated_at)="
                "(select s.provider_slug,s.endpoint_url,s.secret_id,s.enabled,s.max_file_bytes,s.timeout_ms,s.updated_at "
                "from jsonb_populate_record(null::public.document_processor_config,'"+encoded+"'::jsonb) s) where c.singleton;")
            if secret_id:
                sql("delete from vault.secrets where id='"+secret_id+"';")
            if object_path:
                ok(request(api, '/storage/v1/object/documents', 'DELETE', {'prefixes':[object_path]}, elevated=True))
            for user in users:
                ok(request(api, '/auth/v1/admin/users/'+user, 'DELETE', elevated=True), (200, 204))
    report.update(synthetic_users_removed=len(users), original_processor_configuration_restored=True,
        synthetic_vault_secret_removed=True, synthetic_storage_object_removed=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
