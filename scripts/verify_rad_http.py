"""Synthetic HTTP/security/concurrency acceptance against the owned C-002 stack.

Never accepts a hosted URL. Local keys remain in memory and are not reported.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import threading
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--supabase', type=Path, required=True)
    args = parser.parse_args()
    identity = json.loads((args.runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text())
    assert identity['owner_checkout'] == str(ROOT) and identity['project'].startswith('rad_core_')
    assert 58000 <= identity['port'] <= 64000
    port = identity['port']
    status = subprocess.run([str(args.supabase),'--workdir',str(args.runtime),'status','--output','json'],capture_output=True,text=True,check=True)
    settings = {k.lower():v for k,v in json.loads(status.stdout).items()}
    base = settings.get('api_url')
    assert base == f'http://127.0.0.1:{port-1}', 'refusing any other endpoint'
    anon,service = settings['anon_key'],settings['service_role_key']
    report = {'checks': [], 'production_mutations': False, 'endpoint': base}

    def check(name: str, value: bool) -> None:
        if not value: raise AssertionError(name)
        report['checks'].append(name)

    def call(path: str, method='GET', body=None, token=None, headers=None):
        request = urllib.request.Request(base+path,method=method,
            data=None if body is None else json.dumps(body).encode(),
            headers={'apikey':anon,'Authorization':'Bearer '+(token or anon),'Content-Type':'application/json',**(headers or {})})
        try:
            # Never send local test credentials through a system HTTP proxy.
            with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(request,timeout=30) as response:
                raw=response.read();return response.status,json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            raw=error.read()
            try: data=json.loads(raw)
            except ValueError: data=None
            return error.code,data

    def sql(value: str) -> str:
        result = subprocess.run([r'C:\Program Files\PostgreSQL\17\bin\psql.exe','-XAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(port),'-U','postgres','-d','postgres'],
            input=value,text=True,capture_output=True,env={**os.environ,'PGPASSWORD':'postgres'},check=True)
        return result.stdout.strip()

    users=[]
    try:
        for _ in range(2):
            credentials={'email':f'rad-synthetic-{uuid.uuid4().hex}@example.invalid','password':uuid.uuid4().hex+'aA9!'}
            status,payload=call('/auth/v1/signup','POST',credentials)
            if status==429:
                report['signup']='BLOCKED: disposable Auth signup rate limit; used local admin fixture plus real password sign-in'
                status,_=call('/auth/v1/admin/users','POST',{**credentials,'email_confirm':True},service)
                check('local synthetic confirmed Auth fixture',status in (200,201))
                status,payload=call('/auth/v1/token?grant_type=password','POST',credentials)
                check('real Auth password sign-in',status==200 and bool(payload.get('access_token')))
            else:
                check('synthetic Auth signup HTTP '+str(status),status==200 and bool(payload.get('access_token')))
            users.append((payload['user']['id'],payload['access_token']))
        (a,ta),(b,tb)=users
        status,rows=call('/rest/v1/profiles?select=id,role',token=ta)
        check('JWT RLS profile owner isolation',status==200 and [x['id'] for x in rows]==[a] and rows[0]['role']=='user')
        status,_=call('/rest/v1/profiles?id=eq.'+a,'PATCH',{'role':'super_admin'},ta)
        check('HTTP role UPDATE denied',status==403)
        status,_=call('/rest/v1/profiles?id=eq.'+a,'DELETE',token=service)
        check('synthetic orphan fixture created',status==204)
        status,_=call('/rest/v1/profiles','POST',{'id':a,'full_name':'Synthetic owner','role':'admin'},ta)
        check('orphan profile INSERT role escalation denied',status==403)
        status,_=call('/rest/v1/profiles','POST',{'id':a,'full_name':'Synthetic owner'},ta)
        check('safe orphan profile completion succeeds',status==201)
        for schema in ['private','vault']:
            status,_=call('/rest/v1/rad_idempotency?select=*',token=ta,headers={'Accept-Profile':schema})
            check(schema+' schema not exposed',status in (404,406))
        status,_=call('/rest/v1/visa_article_revisions?select=*',token=ta)
        check('direct draft table denied',status==403)
        status,_=call('/rest/v1/rpc/consume_ai_daily_quota','POST',{'p_user_id':a,'p_role':'super_admin'},ta)
        check('quota service boundary denies ordinary JWT',status in (401,403,404))
        status,session=call('/rest/v1/ai_sessions','POST',{'user_id':b,'scope':'user'},tb,{'Prefer':'return=representation'})
        check('owner B session fixture',status==201 and bool(session))
        status,_=call('/rest/v1/ai_session_messages','POST',{'session_id':session[0]['id'],'user_id':a,'role':'user','content':'SYNTHETIC forbidden history'},ta)
        check('cross-user AI history INSERT denied',status==403)
        status,consultation=call('/rest/v1/rpc/submit_consultation_request','POST',{'p_topic':'SYNTHETIC consultation','p_message':'SYNTHETIC intake only, no appointment or payment.','p_related_application_id':None},ta)
        check('confirmed consultation intake succeeds',status==200 and isinstance(consultation,str))
        status,other_consultations=call('/rest/v1/consultation_requests?select=id,topic,message&id=eq.'+consultation,token=tb)
        check('cross-user consultation read hidden',status==200 and other_consultations==[])
        status,changed=call('/rest/v1/consultation_requests?id=eq.'+consultation,'PATCH',{'status':'completed'},tb,{'Prefer':'return=representation'})
        check('cross-user consultation status mutation denied',status in (401,403) or (status==200 and changed==[]))
        status,own_consultation=call('/rest/v1/consultation_requests?select=id,status&id=eq.'+consultation,token=ta)
        check('consultation remains submitted after cross-user PATCH',status==200 and own_consultation[0]['status']=='submitted')
        status,_=call('/rest/v1/rpc/reserve_rad_ai_request','POST',{'p_user_id':a,'p_request_key':str(uuid.uuid4()),'p_body_hash':'a'*64,'p_reserved_output_tokens':4096,'p_session_id':session[0]['id']},service)
        check('service broker verifies session ownership',status==403)
        sql("INSERT INTO public.ai_usage_limits(role,daily_requests,daily_output_tokens) VALUES('user',2,100000) ON CONFLICT(role) DO UPDATE SET daily_requests=2,daily_output_tokens=100000;")
        barrier=threading.Barrier(10)
        requests=[{'p_user_id':a,'p_request_key':str(uuid.uuid4()),'p_body_hash':'b'*64,'p_reserved_output_tokens':4096,'p_session_id':None} for _ in range(10)]
        def reserve(body):
            barrier.wait(timeout=30)
            return call('/rest/v1/rpc/reserve_rad_ai_request','POST',body,service)
        with ThreadPoolExecutor(max_workers=10) as pool: outcomes=list(pool.map(reserve,requests))
        check('all concurrent reservations complete',all(status==200 for status,_ in outcomes))
        admitted=[i for i,(_,data) in enumerate(outcomes) if data.get('allowed') is True]
        check('ten concurrent requests admit exactly two',len(admitted)==2)
        i=admitted[0];reservation=outcomes[i][1]
        status,replay=call('/rest/v1/rpc/reserve_rad_ai_request','POST',requests[i],service)
        check('same key reuses exact reservation',status==200 and replay.get('replayed') is True and replay['request_id']==reservation['request_id'])
        status,_=call('/rest/v1/rpc/reserve_rad_ai_request','POST',{**requests[i],'p_body_hash':'c'*64},service)
        check('changed-body key replay conflicts',status==409)
        status,done=call('/rest/v1/rpc/settle_rad_ai_request','POST',{'p_request_id':reservation['request_id'],'p_http_status':200,'p_response':{'synthetic':True},'p_output_tokens':4},service)
        check('settlement updates same reservation',status==200 and done is True)
        status,again=call('/rest/v1/rpc/settle_rad_ai_request','POST',{'p_request_id':reservation['request_id'],'p_http_status':200,'p_response':{'synthetic':False},'p_output_tokens':4},service)
        check('terminal settlement fenced',status==200 and again is False)
        check('exactly two ai_requests rows',sql(f"SELECT count(*) FROM public.ai_requests WHERE user_id='{a}';")=='2')
        # Legacy and v1 share the same actor/day lock and token reservations.
        mixed_barrier=threading.Barrier(10)
        def mixed(i):
            mixed_barrier.wait(timeout=30)
            if i%2:
                return call('/rest/v1/rpc/consume_ai_daily_quota','POST',{'p_user_id':b,'p_role':'super_admin'},service)
            return call('/rest/v1/rpc/reserve_rad_ai_request','POST',{'p_user_id':b,'p_request_key':str(uuid.uuid4()),'p_body_hash':'d'*64,'p_reserved_output_tokens':4096,'p_session_id':None},service)
        with ThreadPoolExecutor(max_workers=10) as pool: mixed_results=list(pool.map(mixed,range(10)))
        check('mixed legacy/v1 admit exactly two',sum(s==200 and r.get('allowed') is True for s,r in mixed_results)==2)
        check('mixed legacy/v1 persist exactly two rows',sql(f"SELECT count(*) FROM public.ai_requests WHERE user_id='{b}';")=='2')
        check('mixed outstanding token budget is bounded',int(sql(f"SELECT coalesce(sum(reserved_output_tokens),0) FROM private.rad_ai_invocations WHERE actor='{b}' AND state='running';")) in (8192,10240,12288))
        report['admitted_unique_reservations']=len(admitted)
        report['status']='PASS'
    except Exception:
        report['status']='FAIL'
        raise
    finally:
        # Leave fixtures confined to this disposable marked environment. Retain
        # accounting rows for independent review; stop destroys the owned stack.
        (args.runtime/'http_acceptance.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
        print(json.dumps(report,indent=2))


if __name__=='__main__':main()
