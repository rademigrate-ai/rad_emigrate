#!/usr/bin/env python3
"""Loopback Deno HTTP -> real PostgREST -> sandbox SQL integration, no real provider."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime,timedelta,timezone
import argparse
import hashlib
import hmac
import json
import os
from pathlib import Path
import secrets
import shlex
import socket
import subprocess
import time
import urllib.error
import urllib.request
import uuid

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--supabase',required=True,type=Path)
    parser.add_argument('--psql',required=True,type=Path)
    parser.add_argument('--deno',required=True,type=Path)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    project=os.environ.get('RAD_LOCAL47_PROJECT','rad_codex_local47')
    port=int(os.environ.get('RAD_LOCAL47_PORT','55322'))
    runtime=Path(os.environ.get('TEMP','/tmp'))/project
    marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text(encoding='utf-8'))
    assert marker=={'project':project,'source':str(ROOT),'port':port},'wrong local runtime owner'
    status=subprocess.run([str(args.supabase.resolve()),'--workdir',str(runtime),'status','--output','env'],capture_output=True,text=True,encoding='utf-8',check=True)
    values={}
    for line in status.stdout.splitlines():
        parts=shlex.split(line,comments=True)
        if parts and '=' in parts[0]:
            key,value=parts[0].split('=',1);values[key]=value
    api=values['API_URL'];service=values['SERVICE_ROLE_KEY']
    assert api.rstrip('/')==f'http://127.0.0.1:{port-1}','refusing non-owned API target'
    env=os.environ.copy();env['PGPASSWORD']='postgres'
    psql=[str(args.psql.resolve()),'-XqAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(port),'-U','postgres','-d','postgres']
    def sql(source):
        result=subprocess.run(psql,input=source,env=env,capture_output=True,text=True,encoding='utf-8',check=True)
        lines=[line for line in result.stdout.splitlines() if line.strip()]
        return json.loads(lines[-1]) if lines else None
    original=sql('select to_json(enabled) from private.payment_sandbox_config where singleton;')
    assert sql("select to_json(count(*)) from public.notification_deliveries where status in ('queued','processing');")==0,'pending work from another test'
    before=sql("select to_json(md5(coalesce(jsonb_agg(to_jsonb(e) order by id)::text,'[]'))) from public.ai_entitlements e;")
    owner=None;owned_users=[];notification=str(uuid.uuid4());subscription='http-'+uuid.uuid4().hex
    api_port=port-1  # captured before `port` is reused for the random harness listener
    with socket.socket() as probe:
        probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
    secret=secrets.token_urlsafe(48);test_token=secrets.token_urlsafe(48)
    server_env=env.copy();server_env.update(SUPABASE_URL=api,SUPABASE_SERVICE_ROLE_KEY=service,RAD_PAYMENT_SANDBOX_ENABLED='true',
      RAD_PAYMENT_SANDBOX_SECRET=secret,RAD_LOCAL47_TEST_TOKEN=test_token,RAD_LOCAL47_TEST_PORT=str(port))
    allowed='SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY,RAD_PAYMENT_SANDBOX_ENABLED,RAD_PAYMENT_SANDBOX_SECRET,RAD_LOCAL47_TEST_TOKEN,RAD_LOCAL47_TEST_PORT'
    process=subprocess.Popen([str(args.deno.resolve()),'run','--allow-env='+allowed,f'--allow-net=127.0.0.1:{api_port},127.0.0.1:{port}',
      str(ROOT/'scripts/local47_http_harness.ts')],env=server_env,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,
      creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
    def request(path,payload,headers=None):
        data=payload if isinstance(payload,bytes) else json.dumps(payload,separators=(',',':')).encode()
        req=urllib.request.Request(f'http://127.0.0.1:{port}'+path,data=data,headers={'Content-Type':'application/json',**(headers or {})},method='POST')
        try:
            with urllib.request.urlopen(req,timeout=20) as response:return response.status,json.loads(response.read())
        except urllib.error.HTTPError as error:return error.code,json.loads(error.read())
    def payment(event,wrong=False,old=False):
        raw=json.dumps(event,separators=(',',':')).encode();timestamp=str(int(time.time())-(301 if old else 0))
        digest=hmac.new(('wrong-key' if wrong else secret).encode(),timestamp.encode()+b'.'+raw,hashlib.sha256).hexdigest()
        return request('/payment',raw,{'x-rad-sandbox-signature':f't={timestamp},v1={digest}'})
    def api_request(path,payload,token=None):
        credential=token or service
        req=urllib.request.Request(api+path,data=json.dumps(payload).encode(),
          headers={'apikey':values['ANON_KEY'] if token else service,'Authorization':'Bearer '+credential,
                   'Content-Type':'application/json'},method='POST')
        try:
            with urllib.request.urlopen(req,timeout=20) as response:return response.status,json.loads(response.read())
        except urllib.error.HTTPError as error:return error.code,json.loads(error.read())
    def account():
        email='phase24-'+uuid.uuid4().hex+'@example.invalid';password=secrets.token_urlsafe(32)
        code,user=api_request('/auth/v1/admin/users',{'email':email,'password':password,'email_confirm':True})
        assert code in (200,201),'synthetic account creation status '+str(code)
        owned_users.append(user['id'])
        code,login=api_request('/auth/v1/token?grant_type=password',{'email':email,'password':password},values['ANON_KEY'])
        assert code==200,'synthetic login status '+str(code)
        return user['id'],login['access_token']
    report={'scope':'local_Deno_HTTP_PostgREST_SQL','production_mutations':False,'external_provider_calls':0}
    report.update(captured_at=datetime.now(timezone.utc).isoformat(),
      source_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
      source_dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip()))
    try:
        deadline=time.monotonic()+20
        while True:
            if process.poll() is not None:raise AssertionError('local Deno harness exited before listening')
            try:
                with socket.create_connection(('127.0.0.1',port),timeout=.2):break
            except OSError:
                if time.monotonic()>deadline:raise AssertionError('local Deno harness did not start')
                time.sleep(.1)
        owner,owner_token=account();other,other_token=account()
        sql(f"""begin; set local request.jwt.claims='{{"role":"service_role"}}';
insert into public.notification_preferences(user_id,email_enabled) values('{owner}',true) on conflict(user_id) do update set email_enabled=true;
insert into public.notifications(id,user_id,type,title,body) values('{notification}','{owner}','system','Synthetic HTTP notice','No external recipient');
update private.payment_sandbox_config set enabled=true;commit;""")
        now=datetime.now(timezone.utc)
        request_key=str(uuid.uuid4())
        def create_checkout(_):return api_request('/rest/v1/rpc/create_mock_checkout',{'p_request_key':request_key},owner_token)
        with ThreadPoolExecutor(max_workers=8) as pool:created=list(pool.map(create_checkout,range(16)))
        assert all(code==200 for code,_ in created),'mock checkout creation failed'
        checkout=created[0][1]
        assert all(body['order_id']==checkout['order_id'] for _,body in created),'duplicate checkout orders'
        assert checkout['mode']=='mock' and checkout['no_charge'] and not checkout['mock_access_active']
        order={'p_order_id':checkout['order_id']}
        assert api_request('/rest/v1/rpc/get_mock_checkout',order,other_token)[0]==404
        assert api_request('/rest/v1/rpc/request_mock_checkout_cancellation',order,other_token)[0]==404
        assert api_request('/rest/v1/rpc/create_mock_checkout',{'p_request_key':str(uuid.uuid4()),'user_id':other},owner_token)[0] in (400,404)
        mock_event={'mode':'sandbox','event_id':'mock-'+uuid.uuid4().hex,'subscription_id':checkout['subscription_id'],
          'user_id':owner,'type':'payment_succeeded','sequence':1,'amount_minor':checkout['amount_minor'],
          'currency':checkout['currency'],'occurred_at':now.isoformat(),'period_end':checkout['period_end']}
        assert payment(mock_event,wrong=True)[0]==401
        assert payment({**mock_event,'amount_minor':1})[0]==422
        assert payment({**mock_event,'user_id':other})[0]==422
        with ThreadPoolExecutor(max_workers=8) as pool:confirmed=list(pool.map(lambda _:payment(mock_event),range(16)))
        assert all(code==200 for code,_ in confirmed) and sum(not body['duplicate'] for _,body in confirmed)==1
        assert api_request('/rest/v1/rpc/get_mock_checkout',order,owner_token)[1]['mock_access_active']
        assert api_request('/rest/v1/rpc/request_mock_checkout_cancellation',order,owner_token)[1]['cancellation_requested']
        assert payment({**mock_event,'event_id':'cancel-'+uuid.uuid4().hex,'type':'subscription_cancelled','sequence':2,'amount_minor':0})[0]==200
        assert not api_request('/rest/v1/rpc/get_mock_checkout',order,owner_token)[1]['mock_access_active']
        refund={**mock_event,'event_id':'refund-'+uuid.uuid4().hex,'type':'payment_refunded','sequence':3}
        with ThreadPoolExecutor(max_workers=8) as pool:refunded=list(pool.map(lambda _:payment(refund),range(16)))
        assert all(code==200 for code,_ in refunded) and sum(not body['duplicate'] for _,body in refunded)==1
        assert api_request('/rest/v1/rpc/get_mock_checkout',order,owner_token)[1]['status']=='refunded'
        event={'mode':'sandbox','event_id':'http-'+uuid.uuid4().hex,'subscription_id':subscription,'user_id':owner,'type':'payment_succeeded',
          'sequence':1,'amount_minor':100,'currency':'TST','occurred_at':now.isoformat(),'period_end':(now+timedelta(days=1)).isoformat()}
        assert payment(event,wrong=True)[0]==401
        assert payment(event,old=True)[0]==401
        with ThreadPoolExecutor(max_workers=8) as pool:responses=list(pool.map(lambda _:payment(event),range(16)))
        assert all(code==200 for code,_ in responses)
        assert sum(not body['duplicate'] for _,body in responses)==1,'HTTP retry created multiple payment events'
        assert payment({**event,'event_id':'refund-'+uuid.uuid4().hex,'sequence':3,'type':'payment_refunded'})[0]==200
        assert payment({**event,'event_id':'late-'+uuid.uuid4().hex,'sequence':2})[1]['decision']=='ignored_stale'
        assert payment({**event,'event_id':'resurrection-'+uuid.uuid4().hex,'sequence':4})[1]['decision']=='ignored_terminal'
        assert sql(f"select to_json(status) from public.sandbox_payment_subscriptions where subscription_id='{subscription}';")=='refunded'
        # Queue through real PostgREST, then dispatch through the actual worker.
        queued=urllib.request.Request(api+'/rest/v1/rpc/queue_notification_delivery',data=json.dumps({'p_notification_id':notification,'p_channel':'email'}).encode(),
          headers={'apikey':service,'Authorization':'Bearer '+service,'Content-Type':'application/json'},method='POST')
        with urllib.request.urlopen(queued,timeout=10) as response:delivery=json.loads(response.read())
        assert delivery['transport']=='sandbox'
        assert request('/dispatch-endpoint',{}, {'x-rad-notification-token':'wrong'})[0]==403
        assert request('/dispatch-endpoint',{}, {'Authorization':'Bearer '+service})[0]==403
        assert request('/dispatch-endpoint',{'limit':21}, {'x-rad-notification-token':test_token})[0]==400
        code,dispatch=request('/dispatch-endpoint',{}, {'x-rad-notification-token':test_token})
        assert code==200 and dispatch['mode']=='sandbox' and dispatch['sandbox_receipts']==1
        assert sql(f"select to_json(status) from public.notification_deliveries where id='{delivery['delivery_id']}';")=='sandbox_delivered'
        assert request('/dispatch-endpoint',{}, {'x-rad-notification-token':test_token})[1]['sandbox_receipts']==0
        after=sql("select to_json(md5(coalesce(jsonb_agg(to_jsonb(e) order by id)::text,'[]'))) from public.ai_entitlements e;")
        assert before==after,'HTTP sandbox changed canonical entitlements'
        report.update(status='PASS',payment_retry_requests=16,payment_insert_winners=1,forged_signature_denied=True,stale_signature_denied=True,
          delayed_event_ignored=True,terminal_subscription_not_reactivated=True,notification_sandbox_receipts=1,notification_replay_receipts=0,
          canonical_entitlements_unchanged=True,notification_endpoint_purpose_token_required=True,
          notification_endpoint_factory_tested=True,edge_gateway_tested=False,
          mock_checkout_concurrent_creations=16,mock_confirmation_concurrent_callbacks=16,mock_refund_concurrent_callbacks=16,
          mock_checkout_owner_isolation=True,mock_creation_confirmation_cancellation_refund=True,real_auth_login=True)
    finally:
        try:
            ids=','.join("'"+str(uuid.UUID(uid))+"'" for uid in owned_users)
            cleanup='delete from auth.users where id in ('+ids+');' if ids else ''
            sql(f"begin;set local request.jwt.claims='{{\"role\":\"service_role\"}}';{cleanup}update private.payment_sandbox_config set enabled={'true' if original else 'false'};commit;")
        finally:
            process.terminate()
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
