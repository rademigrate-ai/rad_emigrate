import datetime, hashlib, json, os, pathlib, subprocess, sys, time
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate')
ROOT=BASE/'rad_final_independent_audit'
RUNTIME=BASE/('_local_audit_'+sys.argv[1])
OUT=BASE/'_final_independent_evidence_20261020'
marker=json.loads((RUNTIME/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text())
assert marker=={'project':'rad_audit_'+sys.argv[1],'port':62322 if sys.argv[1]=='canonical' else 63322,'owner_checkout':str(ROOT)}
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()=='1fe44f63d179263c5e719578bf7ebad0e17868d1'
ports=json.loads(subprocess.check_output(['docker','inspect','--format','{{json .NetworkSettings.Ports}}','supabase_db_'+marker['project']],text=True))
assert any(int(x['HostPort'])==marker['port'] for x in ports['5432/tcp'])
files=[ROOT/'supabase/reconciliation/security_regression.sql']
files += [ROOT/('supabase/tests/'+n+'.sql') for n in ['phase_a_constraint_backfill','phase_a_security','stage2_knowledge_completion','stage4_user_ai','local47_crm_notifications','local47_payment_sandbox','local47_definer_acl','local47_document_processing','local47_observability']]
files+=sorted((ROOT/'supabase/tests').glob('rad_*.sql'))
files.append(BASE/'rad_core_security_final/supabase/tests/rad_quota_security.sql')
db=[r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(marker['port']),'-U','postgres','-d','postgres']
rows=[]
for path in files:
    start=time.monotonic()
    try:
        p=subprocess.run([*db,'-f',str(path)],cwd=ROOT,env={**os.environ,'PGPASSWORD':'postgres'},capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=300)
        log=OUT/(sys.argv[1]+'_'+path.stem+'.log');log.write_text(p.stdout+p.stderr,encoding='utf-8')
        row={'file':str(path),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'exit_code':p.returncode,'status':'PASS' if p.returncode==0 else 'FAIL','seconds':round(time.monotonic()-start,2),'log':str(log),'error_lines':[s for s in p.stderr.splitlines() if 'ERROR:' in s]}
    except subprocess.TimeoutExpired:row={'file':str(path),'status':'TIMEOUT','exit_code':None}
    rows.append(row);print(json.dumps(row),flush=True)
    (OUT/(sys.argv[1]+'_sql.json')).write_text(json.dumps({'candidate_sha':'1fe44f63d179263c5e719578bf7ebad0e17868d1','runtime':marker,'results':rows},indent=2),encoding='utf-8')
