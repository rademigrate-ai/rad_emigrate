import concurrent.futures,datetime,json,os,pathlib,subprocess,uuid
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate');ROOT=BASE/'rad_final_independent_audit';OUT=BASE/'_final_independent_evidence_20261020'
runtime=BASE/'_local_audit_canonical';marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text())
assert marker=={'project':'rad_audit_canonical','port':62322,'owner_checkout':str(ROOT)}
ports=json.loads(subprocess.check_output(['docker','inspect','--format','{{json .NetworkSettings.Ports}}','supabase_db_rad_audit_canonical'],text=True));assert any(x['HostPort']=='62322' for x in ports['5432/tcp'])
db=[r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-XAtq','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p','62322','-U','postgres','-d','postgres']
def sql(s):
    p=subprocess.run(db,input=s,text=True,capture_output=True,encoding='utf-8',errors='replace',env={**os.environ,'PGPASSWORD':'postgres'},timeout=90)
    if p.returncode:raise RuntimeError('local_sql_failure: '+next((x for x in p.stderr.splitlines() if 'ERROR' in x),'unknown'))
    return p.stdout.strip()
users=[str(uuid.uuid4()),str(uuid.uuid4())]
sql("insert into auth.users(id,email) values "+','.join("('"+u+"','rad-synthetic-"+u+"@example.invalid')" for u in users)+";insert into public.ai_usage_limits(role,daily_requests,daily_output_tokens) values('user',2,100000) on conflict(role) do update set daily_requests=2,daily_output_tokens=100000;")
def reserve(pair):
    index,user=pair
    fn=("public.consume_ai_daily_quota('"+user+"','super_admin')") if index%2 else ("public.reserve_rad_ai_request('"+user+"','"+str(uuid.uuid4())+"','"+('a'*64)+"',4096,null)")
    response=sql("begin;set local role service_role;set local request.jwt.claims='{}';select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);select "+fn+";commit;")
    return json.loads(response.splitlines()[-1])
rows=[]
for user in users:
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:results=list(pool.map(reserve,[(i,user) for i in range(10)]))
    admitted=sum(r.get('allowed') is True for r in results)
    count=int(sql("select count(*) from public.ai_requests where user_id='"+user+"';"))
    rows.append({'concurrent_mixed_legacy_v1':10,'admitted':admitted,'persisted_rows':count,'requested_role':'super_admin','actual_profile_role':'user','status':'PASS' if admitted==count==2 else 'FAIL'})
report={'candidate_sha':'1fe44f63d179263c5e719578bf7ebad0e17868d1','captured_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'endpoint':'127.0.0.1:62322','fixture':'Disposable random synthetic Auth users; server-side service-role calls; no providers','production_mutations':False,'results':rows}
(OUT/'quota_concurrency.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report,indent=2))
