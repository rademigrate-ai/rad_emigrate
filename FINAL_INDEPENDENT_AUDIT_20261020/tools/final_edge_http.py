"""Execute candidate handlers on loopback; deny all external network access."""
import json,os,pathlib,subprocess,time,urllib.request,urllib.error,uuid
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate');ROOT=BASE/'rad_final_independent_audit';OUT=BASE/'_final_independent_evidence_20261020'
runtime=BASE/'_local_audit_canonical';marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text());assert marker=={'project':'rad_audit_canonical','port':62322,'owner_checkout':str(ROOT)}
CLI=r'C:\Users\Mehrshad\AppData\Local\npm-cache\_npx\aa8e5c70f9d8d161\node_modules\@supabase\cli-windows-x64\bin\supabase.exe'
status=json.loads(subprocess.check_output([CLI,'--workdir',str(runtime),'status','--output','json'],text=True,stderr=subprocess.DEVNULL));settings={k.lower():v for k,v in status.items()};assert settings['api_url']=='http://127.0.0.1:62321'
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
def call(url,body=None,headers=None):
    request=urllib.request.Request(url,data=None if body is None else json.dumps(body).encode(),headers={'Content-Type':'application/json',**(headers or {})})
    try:
        with opener.open(request,timeout=25) as response:return response.status,json.loads(response.read())
    except urllib.error.HTTPError as e:return e.code,json.loads(e.read())
headers={'apikey':settings['anon_key'],'Authorization':'Bearer '+settings['service_role_key']}
credentials={'email':'rad-synthetic-edge-'+uuid.uuid4().hex+'@example.invalid','password':uuid.uuid4().hex+'aA9!','email_confirm':True}
code,user=call(settings['api_url']+'/auth/v1/admin/users',credentials,headers);assert code in (200,201)
code,session=call(settings['api_url']+'/auth/v1/token?grant_type=password',{'email':credentials['email'],'password':credentials['password']},{'apikey':settings['anon_key']});assert code==200
bootstrap=OUT/'edge_loopback_bootstrap.ts'
bootstrap.write_text('import {handler as ai} from '+json.dumps((ROOT/'supabase/functions/ai-orchestrator/handler.ts').as_uri())+';\nimport {handler as research} from '+json.dumps((ROOT/'supabase/functions/research-sync/handler.ts').as_uri())+';\nDeno.serve({hostname:"127.0.0.1",port:64451},r=>new URL(r.url).pathname==="/ai"?ai(r):research(r));\n',encoding='utf-8')
command=[str(pathlib.Path.home()/'.deno/bin/deno.exe'),'run','--cached-only','--allow-env=SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY','--allow-net=127.0.0.1:62321,127.0.0.1:64451',str(bootstrap)]
results=[];process=None
def check(name,valid,code):
    results.append({'check':name,'status':'PASS' if valid else 'FAIL','http_status':code})
try:
    log=(OUT/'edge_http_runtime.log').open('w',encoding='utf-8')
    process=subprocess.Popen(command,cwd=ROOT,env={**os.environ,'SUPABASE_URL':settings['api_url'],'SUPABASE_SERVICE_ROLE_KEY':settings['service_role_key']},stdout=log,stderr=subprocess.STDOUT)
    for _ in range(30):
        if process.poll() is not None:raise RuntimeError('local_handler_process_exited')
        try:
            code,payload=call('http://127.0.0.1:64451/ai',{})
            break
        except urllib.error.URLError:time.sleep(0.5)
    else:raise RuntimeError('local_handler_startup_timeout')
    code,payload=call('http://127.0.0.1:64451/ai',{'action':'chat','messages':[{'role':'user','content':'SYNTHETIC audit query'}]})
    check('legacy AI unauthenticated request denied',code==401,code)
    contract={'action':'chat','request_key':str(uuid.uuid4()),'session_id':None,'guest_key':None,'locale':'en','messages':[{'role':'user','content':'SYNTHETIC audit query'}],'context':{'article_id':None,'section_id':None,'case_id':None},'authorized_data_scopes':[],'scope':'user'}
    code,payload=call('http://127.0.0.1:64451/ai',contract,{'x-rad-contract-version':'1'})
    check('v1 AI requires real Auth user',code==401,code)
    code,payload=call('http://127.0.0.1:64451/ai',contract,{'x-rad-contract-version':'1','Authorization':'Bearer '+session['access_token']})
    data=payload.get('data',{})
    check('v1 real Auth to reservation to no-evidence response',code==200 and data.get('evidence_state') in ('insufficient','unavailable') and data.get('citations')==[],code)
    code,payload=call('http://127.0.0.1:64451/research',{})
    check('research rejects missing worker/admin authorization',code==403,code)
    report={'candidate_sha':'1fe44f63d179263c5e719578bf7ebad0e17868d1','status':'PASS' if all(r['status']=='PASS' for r in results) else 'FAIL','checks':results,'network_allowlist':['127.0.0.1:62321','127.0.0.1:64451'],'providers_called':False,'production_mutations':False,'scope':'Actual Deno handlers + actual disposable Auth/PostgREST; no Supabase gateway/runtime emulation, Flutter UI, or live providers','command':command}
except Exception as e:report={'candidate_sha':'1fe44f63d179263c5e719578bf7ebad0e17868d1','status':'FAIL','error':type(e).__name__+':'+str(e),'checks':results}
finally:
    if process and process.poll() is None:process.terminate();process.wait(timeout=15)
    (OUT/'edge_http.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report,indent=2))
