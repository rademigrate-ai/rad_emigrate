"""Restore captured PG17 MAINTAIN ACLs in the audit-owned reconstruction only."""
import hashlib,json,os,pathlib,subprocess
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate');ROOT=BASE/'rad_final_security_remediation';OUT=BASE/'_security_remediation_20261020';runtime=BASE/'_local_security_remed_upgrade'
marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text());assert marker=={'project':'rad_core_remed_upgrade','port':63522,'owner_checkout':str(ROOT)}
ports=json.loads(subprocess.check_output(['docker','inspect','--format','{{json .NetworkSettings.Ports}}','supabase_db_rad_core_remed_upgrade'],text=True));assert any(p['HostPort']=='63522' for p in ports['5432/tcp'])
rows=json.loads((OUT/'hosted_maintain_grants.json').read_text())
def q(s):return '"'+s.replace('"','""')+'"'
sql='begin;\n'+'\n'.join('GRANT MAINTAIN ON TABLE '+q(r['schema'])+'.'+q(r['table_name'])+' TO '+('PUBLIC' if r['grantee']=='PUBLIC' else q(r['grantee']))+(' WITH GRANT OPTION' if r['is_grantable'] else '')+';' for r in rows)+'\ncommit;'
(OUT/'local_maintain_supplement.sql').write_text(sql,encoding='utf-8')
db=[r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-XAtq','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p','63522','-U','postgres','-d','postgres']
subprocess.run(db,input=sql,text=True,capture_output=True,check=True,env={**os.environ,'PGPASSWORD':'postgres'})
report={'scope':'Local metadata reconstruction supplement only, not a hosted migration','reason':'information_schema.table_privileges omits PostgreSQL 17 MAINTAIN; prior ten-dimension comparison did not cover it','captured_rows':len(rows),'sql_sha256':hashlib.sha256(sql.encode()).hexdigest(),'production_mutations':False,'status':'PASS'}
(OUT/'maintain_supplement.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))
