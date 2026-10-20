import hashlib,json,os,pathlib,subprocess
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate');ROOT=BASE/'rad_final_independent_audit';OUT=BASE/'_final_independent_evidence_20261020'
runtime=BASE/'_local_audit_canonical';marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text());assert marker=={'project':'rad_audit_canonical','port':62322,'owner_checkout':str(ROOT)}
ports=json.loads(subprocess.check_output(['docker','inspect','--format','{{json .NetworkSettings.Ports}}','supabase_db_rad_audit_canonical'],text=True));assert any(x['HostPort']=='62322' for x in ports['5432/tcp'])
source=OUT/'snapshot_immutability_probe.sql'
command=[r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p','62322','-U','postgres','-d','postgres','-f',str(source)]
p=subprocess.run(command,env={**os.environ,'PGPASSWORD':'postgres'},capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
(OUT/'snapshot_immutability_probe.log').write_text(p.stdout+p.stderr,encoding='utf-8')
report={'candidate_sha':'1fe44f63d179263c5e719578bf7ebad0e17868d1','exit_code':p.returncode,'status':'PASS' if p.returncode==0 else 'FAIL','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'error_lines':[s for s in p.stderr.splitlines() if 'ERROR' in s],'meaning':'Privileged ingestion boundary must preserve referenced snapshot bytes; this is not an anonymous table-write exploit.'}
(OUT/'snapshot_immutability_probe.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report,indent=2))
