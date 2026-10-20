import hashlib,json,pathlib,subprocess,sys,types
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate');ROOT=BASE/'rad_final_independent_audit'
source=BASE/'rad_core_security_final/scripts/verify_rad_http.py'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()=='1fe44f63d179263c5e719578bf7ebad0e17868d1'
runtime=BASE/'_local_audit_canonical';marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text())
assert marker=={'project':'rad_audit_canonical','port':62322,'owner_checkout':str(ROOT)}
ports=json.loads(subprocess.check_output(['docker','inspect','--format','{{json .NetworkSettings.Ports}}','supabase_db_rad_audit_canonical'],text=True))
assert any(x['HostPort']=='62322' for x in ports['5432/tcp'])
text=source.read_text(encoding='utf-8').replace("startswith('rad_core_')","startswith('rad_audit_')")
(BASE/'_final_independent_evidence_20261020/http_harness.json').write_text(json.dumps({'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'transformation':"Assert dedicated rad_audit_ project prefix; ROOT points to immutable audit candidate. No behavior assertions changed."},indent=2),encoding='utf-8')
module=types.ModuleType('audit_http_harness');module.__file__=str(source)
exec(compile(text,str(source),'exec'),module.__dict__);module.ROOT=ROOT
sys.argv=[str(source),'--runtime',str(runtime),'--supabase',r'C:\Users\Mehrshad\AppData\Local\npm-cache\_npx\aa8e5c70f9d8d161\node_modules\@supabase\cli-windows-x64\bin\supabase.exe']
module.main()
