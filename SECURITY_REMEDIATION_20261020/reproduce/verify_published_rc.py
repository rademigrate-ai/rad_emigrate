"""Exact published RC re-verification in separate owned disposable projects."""
import hashlib,json,os,pathlib,shutil,subprocess,sys,time
BASE=next(p for p in pathlib.Path(__file__).resolve().parents if (p/'rad_final_security_remediation').is_dir() and (p/'_security_remediation_20261020').is_dir());OUT=BASE/'_security_remediation_20261020';ROOT=BASE/'rad_security_verify_b01f625';OLD=BASE/'rad_final_security_remediation'
SHA='b01f6255c9f10baff1ff12c1df07b1d995fad8a8';assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()==SHA
CLI=r'C:\Users\Mehrshad\AppData\Local\npm-cache\_npx\aa8e5c70f9d8d161\node_modules\@supabase\cli-windows-x64\bin\supabase.exe'
kind=sys.argv[1];assert kind in ('canonical','upgrade')
port=62522 if kind=='canonical' else 63522
runtime=BASE/('_local_security_b01_'+kind);old_runtime=BASE/('_local_security_remed_'+kind)
def run(name,cmd,cwd=ROOT,env=None,required=True):
 start=time.monotonic()
 with (OUT/('b01_'+name+'.log')).open('w',encoding='utf-8') as log:r=subprocess.run(cmd,cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1800,shell=isinstance(cmd,str))
 report={'candidate_sha':SHA,'command':cmd,'exit_code':r.returncode,'seconds':round(time.monotonic()-start,2),'log_sha256':hashlib.sha256((OUT/('b01_'+name+'.log')).read_bytes()).hexdigest()}
 (OUT/('b01_'+name+'.json')).write_text(json.dumps(report,indent=2),encoding='utf-8');print(name,r.returncode,flush=True)
 if required:assert r.returncode==0,name
 return r.returncode
common=['--project','rad_core_b01_'+kind,'--port',str(port),'--runtime',str(runtime),'--evidence',str(BASE/'_audit/C002_C003_20261019/evidence'),'--supabase',CLI]
old_common=['--project','rad_core_remed_'+kind,'--port',str(port),'--runtime',str(old_runtime),'--evidence',str(BASE/'_audit/C002_C003_20261019/evidence'),'--supabase',CLI]
marker=json.loads((old_runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text());assert marker=={'project':'rad_core_remed_'+kind,'port':port,'owner_checkout':str(OLD)}
run(kind+'_old_stop',[sys.executable,'scripts/rad_local_rehearsal.py','stop',*old_common],cwd=OLD)
shutil.copyfile(old_runtime/'stop_report.json',OUT/(kind+'_remed_stop_report.json'))
run(kind+'_start',[sys.executable,'scripts/rad_local_rehearsal.py','start',*common])
for op in (['canonical'] if kind=='canonical' else ['reconstruct']):
 run(kind+'_'+op,[sys.executable,'scripts/rad_local_rehearsal.py',op,*common])
 shutil.copyfile(runtime/(op+'_report.json'),OUT/('b01_'+kind+'_'+op+'_report.json'))
if kind=='upgrade':
 marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text());assert marker=={'project':'rad_core_b01_upgrade','port':63522,'owner_checkout':str(ROOT)}
 ports=json.loads(subprocess.check_output(['docker','inspect','--format','{{json .NetworkSettings.Ports}}','supabase_db_rad_core_b01_upgrade'],text=True));assert any(p['HostPort']=='63522' for p in ports['5432/tcp'])
 sql=(OUT/'local_maintain_supplement.sql').read_text()
 result=subprocess.run([r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-XAtq','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p','63522','-U','postgres','-d','postgres'],input=sql,text=True,capture_output=True,env={**os.environ,'PGPASSWORD':'postgres'},check=True)
 for op in ['compare','upgrade']:
  run(kind+'_'+op,[sys.executable,'scripts/rad_local_rehearsal.py',op,*common])
  shutil.copyfile(runtime/(op+'_report.json'),OUT/('b01_'+kind+'_'+op+'_report.json'))
run(kind+'_sql',[sys.executable,'scripts/rad_backend_regression.py','--runtime',str(runtime)])
shutil.copyfile(runtime/'backend_regression.json',OUT/('b01_'+kind+'_regression.json'))
# New correction is absent in this RC. Run its rollback test from the already
# published fix path, without copying a file or applying the fix to this RC.
marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text());assert marker['owner_checkout']==str(ROOT)
db=[r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(port),'-U','postgres','-d','postgres']
run(kind+'_missing_fix_probe',[*db,'-f',str(OLD/'supabase/tests/rad_client_table_privileges.sql')],env={**os.environ,'PGPASSWORD':'postgres'},required=False)
if kind=='canonical':
 run('http_security',[sys.executable,'scripts/verify_rad_http.py','--runtime',str(runtime),'--supabase',CLI])
 shutil.copyfile(runtime/'http_acceptance.json',OUT/'b01_http_acceptance.json')
 env={**os.environ,'PATH':str(pathlib.Path(CLI).parent)+os.pathsep+os.environ['PATH'],'NO_PROXY':'127.0.0.1,localhost','HTTP_PROXY':'','HTTPS_PROXY':''}
 run('auth_storage',[sys.executable,str(ROOT/'scripts/verify_local_auth_isolation.py')],cwd=runtime,env=env)
