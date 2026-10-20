import pathlib,subprocess,sys
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate')
ROOT=BASE/'rad_final_independent_audit'
CLI=r'C:\Users\Mehrshad\AppData\Local\npm-cache\_npx\aa8e5c70f9d8d161\node_modules\@supabase\cli-windows-x64\bin\supabase.exe'
for operation in ['reconstruct','compare','upgrade']:
    command=[sys.executable,str(pathlib.Path(__file__).parent/'final_rehearsal.py'),operation,'--project','rad_audit_upgrade','--port','63322','--runtime',str(BASE/'_local_audit_upgrade'),'--evidence',str(BASE/'_audit/C002_C003_20261019/evidence'),'--supabase',CLI]
    subprocess.run(command,cwd=ROOT,check=True)
subprocess.run([sys.executable,str(pathlib.Path(__file__).parent/'final_sql_checks.py'),'upgrade'],cwd=ROOT,check=True)
