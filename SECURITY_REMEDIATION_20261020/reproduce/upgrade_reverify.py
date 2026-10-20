import json,pathlib,shutil,subprocess,sys
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate');ROOT=BASE/'rad_final_security_remediation';OUT=BASE/'_security_remediation_20261020';runtime=BASE/'_local_security_remed_upgrade'
CLI=r'C:\Users\Mehrshad\AppData\Local\npm-cache\_npx\aa8e5c70f9d8d161\node_modules\@supabase\cli-windows-x64\bin\supabase.exe'
common=['--project','rad_core_remed_upgrade','--port','63522','--runtime',str(runtime),'--evidence',str(BASE/'_audit/C002_C003_20261019/evidence'),'--supabase',CLI]
def run(name,command,required=True):
    with (OUT/(name+'.log')).open('w',encoding='utf-8') as log:p=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    print(name,p.returncode,flush=True)
    if required and p.returncode:raise SystemExit(p.returncode)
for op in ['reset-upgrade','reconstruct']:
    run('fidelity_'+op,[sys.executable,'scripts/rad_local_rehearsal.py',op,*common])
run('maintain_supplement',[sys.executable,str(OUT/'maintain_supplement.py')])
run('fidelity_compare',[sys.executable,'scripts/rad_local_rehearsal.py','compare',*common])
# Test the exact previous RC prefix before the new last migration. The apply
# manifest is explicit; no historical file is executed in this shape.
for path in sorted((ROOT/'supabase/migrations').glob('*.sql')):
    if '20261019204906_'<=path.name<'20261020192732_':
        run('fidelity_apply_'+path.stem,[sys.executable,'scripts/rad_local_rehearsal.py','apply',*common,'--sql',str(path)])
run('fidelity_acl_before',[sys.executable,str(OUT/'acl_state.py'),'upgrade','before'])
run('fidelity_red',[sys.executable,'scripts/rad_local_rehearsal.py','test',*common,'--sql',str(ROOT/'supabase/tests/rad_client_table_privileges.sql')],False)
shutil.copyfile(runtime/'test_report.json',OUT/'upgrade_fidelity_red.json')
run('fidelity_fix',[sys.executable,'scripts/rad_local_rehearsal.py','apply',*common,'--sql',str(ROOT/'supabase/migrations/20261020192732_rad_revoke_client_nonrow_table_privileges.sql')])
shutil.copyfile(runtime/'apply_report.json',OUT/'upgrade_fix_apply.json')
run('fidelity_acl_after',[sys.executable,str(OUT/'acl_state.py'),'upgrade','after'])
run('upgrade_green',[sys.executable,'scripts/rad_backend_regression.py','--runtime',str(runtime)])
shutil.copyfile(runtime/'backend_regression.json',OUT/'upgrade_green.json')
