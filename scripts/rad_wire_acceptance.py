"""Capture real, rolled-back synthetic RPC fixtures in an owned local database."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime',type=Path,required=True)
    parser.add_argument('--psql',default=r'C:\Program Files\PostgreSQL\17\bin\psql.exe')
    args=parser.parse_args()
    identity=json.loads((args.runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text())
    assert identity['owner_checkout']==str(ROOT) and identity['project'].startswith('rad_core_')
    assert 58000<=identity['port']<=64000
    ports=json.loads(subprocess.check_output(['docker','inspect','--format','{{json .NetworkSettings.Ports}}','supabase_db_'+identity['project']],text=True))
    assert any(int(binding['HostPort'])==identity['port'] for binding in ports.get('5432/tcp',[])), 'wrong owned database port'
    registry=json.loads((ROOT/'supabase/contracts/rad_v1.json').read_text(encoding='utf-8'))
    names={e['name'] for e in registry['endpoints'] if e['transport']=='RPC'}
    prelude="""
create temporary table rad_wire(name text,request jsonb,response jsonb);
create function pg_temp.rad_record(name text,request jsonb,response jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare schema jsonb;
begin
 select s.schema into schema from private.rad_contract_schemas s where s.name=rad_record.name||'_response';
 if schema is null or not private.rad_schema_valid(schema,response) then
  raise exception 'wire mismatch for %: %',name,response;
 end if;
 insert into pg_temp.rad_wire values(name,request,response);
 return response;
end $$;
create function pg_temp.rad_capture(name text,request jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare response jsonb;
begin
 execute format('select public.%I($1)',name) into response using request;
 return pg_temp.rad_record(name,request,response);
end $$;
grant execute on function pg_temp.rad_capture(text,jsonb) to authenticated,anon,service_role;
grant execute on function pg_temp.rad_record(text,jsonb,jsonb) to authenticated,anon,service_role;
"""
    all_fixtures=[]
    tests=sorted(p for p in (ROOT/'supabase/tests').glob('rad_*.sql') if not p.name.endswith('_performance.sql'))
    for test in tests:
        sql=test.read_text(encoding='utf-8')
        sql=re.sub(r'\bpublic\.([a-z_]+)\(',lambda m: "pg_temp.rad_capture('"+m[1]+"'," if m[1] in names else m[0],sql)
        assert re.match(r'\A(?:--[^\n]*\n|\s)*begin;',sql,re.IGNORECASE) and sql.rstrip().lower().endswith('rollback;')
        sql=sql.replace('begin;','begin;\n'+prelude,1)
        sql=sql.rsplit('rollback;',1)[0]+"\nreset role;select jsonb_agg(to_jsonb(f)) from pg_temp.rad_wire f;rollback;"
        result=subprocess.run([args.psql,'-XAtq','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(identity['port']),'-U','postgres','-d','postgres'],
            input=sql,encoding='utf-8',capture_output=True,env={**os.environ,'PGPASSWORD':'postgres'})
        if result.returncode:
            (args.runtime/'wire_failure.log').write_text(result.stdout+result.stderr,encoding='utf-8')
            raise RuntimeError(test.name+': see external wire_failure.log')
        rows=[json.loads(line) for line in result.stdout.splitlines() if line.startswith('[{')]
        all_fixtures.extend(rows[-1] if rows else [])
        print(test.name+': PASS')
    directory=ROOT/'supabase/contracts/fixtures'
    directory.mkdir(exist_ok=True)
    (directory/'rad_v1_synthetic.json').write_text(json.dumps(all_fixtures,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Actual SQL request/response fixtures:',len(all_fixtures))


if __name__=='__main__':main()
