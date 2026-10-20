import json,os,pathlib,subprocess,sys
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate');ROOT=BASE/'rad_final_security_remediation';OUT=BASE/'_security_remediation_20261020'
kind,stage=sys.argv[1:];assert kind in ('canonical','upgrade') and stage in ('before','after')
runtime=BASE/('_local_security_remed_'+kind);port=62522 if kind=='canonical' else 63522
marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text());assert marker=={'project':'rad_core_remed_'+kind,'port':port,'owner_checkout':str(ROOT)}
ports=json.loads(subprocess.check_output(['docker','inspect','--format','{{json .NetworkSettings.Ports}}','supabase_db_'+marker['project']],text=True));assert any(int(p['HostPort'])==port for p in ports['5432/tcp'])
db=[r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-XAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(port),'-U','postgres','-d','postgres']
query="""select jsonb_build_object(
'dml',(select jsonb_agg(jsonb_build_array(n.nspname,c.relname,r.name,p.name,has_table_privilege(r.name,c.oid,p.name)) order by c.relname,r.name,p.name) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join(values('anon'),('authenticated'),('service_role'))r(name) cross join(values('SELECT'),('INSERT'),('UPDATE'),('DELETE'))p(name) where n.nspname='public' and c.relkind in('r','p','v','m')),
'rls',(select jsonb_agg(jsonb_build_array(c.relname,c.relrowsecurity,c.relforcerowsecurity) order by c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in('r','p')),
'policies',(select jsonb_agg(to_jsonb(p) order by p.schemaname,p.tablename,p.policyname) from pg_policies p where p.schemaname in('public','private','storage')),
'routines',(select jsonb_agg(jsonb_build_array(n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),md5(pg_get_functiondef(p.oid)),p.proacl::text,p.proconfig) order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','private')),
'service_nonrow',(select jsonb_agg(jsonb_build_array(c.relname,p.name,has_table_privilege('service_role',c.oid,p.name)) order by c.relname,p.name) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join(values('TRUNCATE'),('REFERENCES'),('TRIGGER'),('MAINTAIN'))p(name) where n.nspname='public' and c.relkind in('r','p')),
'client_nonrow',(select coalesce(jsonb_agg(jsonb_build_array(c.relname,r.name,p.name) order by c.relname,r.name,p.name),'[]'::jsonb) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join(values('anon'),('authenticated'))r(name) cross join(values('TRUNCATE'),('REFERENCES'),('TRIGGER'),('MAINTAIN'))p(name) where n.nspname='public' and c.relkind in('r','p') and has_table_privilege(r.name,c.oid,p.name))
)"""
p=subprocess.run(db,input=query,capture_output=True,text=True,encoding='utf-8',env={**os.environ,'PGPASSWORD':'postgres'},check=True);data=json.loads(p.stdout)
(OUT/(kind+'_acl_'+stage+'.json')).write_text(json.dumps(data,indent=2),encoding='utf-8')
if stage=='after':
    old=json.loads((OUT/(kind+'_acl_before.json')).read_text())
    assert data['client_nonrow']==[]
    assert all(old[k]==data[k] for k in ['dml','rls','policies','routines','service_nonrow'])
print(json.dumps({'runtime':kind,'stage':stage,'nonrow_client_grants':len(data['client_nonrow']),'other_contracts_unchanged':stage=='after'}))
