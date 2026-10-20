"""Run existing synthetic evidence suite plus a DELETE negative in owned DBs."""
import hashlib,json,os,pathlib,subprocess,time
BASE=next(p for p in pathlib.Path(__file__).resolve().parents if (p/'rad_final_security_remediation').is_dir() and (p/'_security_remediation_20261020').is_dir());ROOT=BASE/'rad_final_security_remediation';OUT=BASE/'_security_remediation_20261020'
sql=(ROOT/'supabase/tests/rad_official_evidence.sql').read_text(encoding='utf-8')
needle=" begin update public.source_snapshots set normalized_text='tampered';raise exception 'snapshot mutable';exception when sqlstate 'PT409' then null;end;"
assert sql.count(needle)==1 and sql.rstrip().endswith('rollback;')
sql=sql.replace(needle,needle+"\n begin delete from public.source_snapshots where id='f5000000-0000-4000-8000-000000000001';raise exception 'snapshot delete admitted';exception when sqlstate 'PT409' then null;end;")
(OUT/'snapshot_delete_probe.sql').write_text(sql,encoding='utf-8')
rows=[]
for kind,port in [('canonical',62522),('upgrade',63522)]:
 runtime=BASE/('_local_security_remed_'+kind)
 marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text())
 assert marker=={'project':'rad_core_remed_'+kind,'port':port,'owner_checkout':str(ROOT)}
 ports=json.loads(subprocess.check_output(['docker','inspect','--format','{{json .NetworkSettings.Ports}}','supabase_db_'+marker['project']],text=True))
 assert any(int(p['HostPort'])==port for p in ports['5432/tcp'])
 start=time.monotonic()
 result=subprocess.run([r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(port),'-U','postgres','-d','postgres'],input=sql,text=True,capture_output=True,encoding='utf-8',env={**os.environ,'PGPASSWORD':'postgres'})
 log=OUT/('snapshot_delete_'+kind+'.log');log.write_text(result.stdout+result.stderr,encoding='utf-8')
 rows.append({'runtime':kind,'status':'PASS' if result.returncode==0 else 'FAIL','exit_code':result.returncode,'sql_sha256':hashlib.sha256(sql.encode()).hexdigest(),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'seconds':round(time.monotonic()-start,2),'rollback_only':True})
(OUT/'snapshot_delete_probe.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
print(json.dumps(rows,indent=2))
assert all(r['status']=='PASS' for r in rows)
