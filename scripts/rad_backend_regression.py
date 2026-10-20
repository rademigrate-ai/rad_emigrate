"""Run existing backend SQL suites without changing remote databases."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime',type=Path,required=True)
    args=parser.parse_args()
    marker=json.loads((args.runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text())
    assert marker['owner_checkout']==str(ROOT) and marker['project'].startswith('rad_core_')
    ports=json.loads(subprocess.check_output(['docker','inspect','--format','{{json .NetworkSettings.Ports}}','supabase_db_'+marker['project']],text=True))
    assert any(int(binding['HostPort'])==marker['port'] for binding in ports['5432/tcp'])
    files=['supabase/reconciliation/security_regression.sql']+['supabase/tests/'+name+'.sql' for name in [
        'phase_a_constraint_backfill','phase_a_security','stage2_knowledge_completion','stage4_user_ai',
        'local47_crm_notifications','local47_payment_sandbox','local47_definer_acl','local47_document_processing','local47_observability']]
    files+=['supabase/tests/'+p.name for p in sorted((ROOT/'supabase/tests').glob('rad_*.sql'))]
    results=[]
    for filename in files:
        optional={
            'local47_payment_sandbox':"to_regprocedure('public.apply_sandbox_payment_event(jsonb,text)') is not null",
            'local47_document_processing':"to_regclass('private.document_processing_leases') is not null",
            'local47_observability':"to_regclass('public.incident_events') is not null"
        }.get(Path(filename).stem)
        if optional:
            probe=subprocess.check_output([r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-XAt','-h','127.0.0.1','-p',str(marker['port']),'-U','postgres','-d','postgres','-c','select '+optional],
                env={**os.environ,'PGPASSWORD':'postgres'},text=True).strip()
            if probe!='t':
                results.append({'test':filename,'status':'NOT RUN','reason':'Optional component absent from captured baseline; no historical replay authorized for that feature'})
                print('NOT RUN',filename,flush=True)
                continue
        start=time.monotonic()
        run=subprocess.run([r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(marker['port']),'-U','postgres','-d','postgres','-f',filename],cwd=ROOT,
            env={**os.environ,'PGPASSWORD':'postgres'},capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=300)
        result={'test':filename,'status':'PASS' if run.returncode==0 else 'FAIL','seconds':round(time.monotonic()-start,3),'sha256':hashlib.sha256((ROOT/filename).read_bytes()).hexdigest()}
        (args.runtime/(Path(filename).stem+'.log')).write_text(run.stdout+run.stderr,encoding='utf-8')
        results.append(result)
        print(result['status'],filename,flush=True)
    (args.runtime/'backend_regression.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    if any(row['status']=='FAIL' for row in results):raise SystemExit(1)


if __name__=='__main__':main()
