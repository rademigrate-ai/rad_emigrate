import hashlib,json,os,pathlib,subprocess,sys,time
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate');ROOT=BASE/'rad_final_security_remediation';OUT=BASE/'_security_remediation_20261020';runtime=BASE/'_local_security_remed_canonical'
marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text());assert marker=={'project':'rad_core_remed_canonical','port':62522,'owner_checkout':str(ROOT)}
ports=json.loads(subprocess.check_output(['docker','inspect','--format','{{json .NetworkSettings.Ports}}','supabase_db_rad_core_remed_canonical'],text=True));assert any(p['HostPort']=='62522' for p in ports['5432/tcp'])
cli=pathlib.Path(r'C:\Users\Mehrshad\AppData\Local\npm-cache\_npx\aa8e5c70f9d8d161\node_modules\@supabase\cli-windows-x64\bin\supabase.exe')
env={**os.environ,'PATH':str(cli.parent)+os.pathsep+os.environ['PATH'],'NO_PROXY':'127.0.0.1,localhost','HTTP_PROXY':'','HTTPS_PROXY':''}
start=time.monotonic()
with (OUT/'auth_storage.log').open('w',encoding='utf-8') as log:p=subprocess.run([sys.executable,str(ROOT/'scripts/verify_local_auth_isolation.py')],cwd=runtime,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300)
report={'command':'python scripts/verify_local_auth_isolation.py (cwd owned canonical runtime)','exit_code':p.returncode,'seconds':round(time.monotonic()-start,2),'log_sha256':hashlib.sha256((OUT/'auth_storage.log').read_bytes()).hexdigest()}
(OUT/'auth_storage.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))
command=[r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p','62522','-U','postgres','-d','postgres','-f',str(ROOT/'supabase/tests/ai_entitlement_rpc_privacy.sql')]
with (OUT/'entitlement_privacy.log').open('w',encoding='utf-8') as log:q=subprocess.run(command,cwd=ROOT,env={**os.environ,'PGPASSWORD':'postgres'},stdout=log,stderr=subprocess.STDOUT,timeout=120)
(OUT/'entitlement_privacy.json').write_text(json.dumps({'exit_code':q.returncode,'command':command},indent=2),encoding='utf-8');print('entitlement',q.returncode)
