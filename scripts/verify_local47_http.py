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
    owner=str(uuid.uuid4());notification=str(uuid.uuid4());subscription='http-'+uuid.uuid4().hex
    with socket.socket() as probe:
        probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
    secret=secrets.token_urlsafe(48);test_token=secrets.token_urlsafe(48)
    server_env=env.copy();server_env.update(SUPABASE_URL=api,SUPABASE_SERVICE_ROLE_KEY=service,RAD_PAYMENT_SANDBOX_ENABLED='true',
      RAD_PAYMENT_SANDBOX_SECRET=secret,RAD_LOCAL47_TEST_TOKEN=test_token,RAD_LOCAL47_TEST_PORT=str(port))
    allowed='SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY,RAD_PAYMENT_SANDBOX_ENABLED,RAD_PAYMENT_SANDBOX_SECRET,RAD_LOCAL47_TEST_TOKEN,RAD_LOCAL47_TEST_PORT'
    process=subprocess.Popen([str(args.deno.resolve()),'run','--allow-env='+allowed,f'--allow-net=127.0.0.1:55321,127.0.0.1:{port}',
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
        sql(f"""begin; set local request.jwt.claims='{{"role":"service_role"}}';
insert into auth.users(id,email,raw_user_meta_data) values('{owner}','{owner}@example.invalid','{{}}');
insert into public.notification_preferences(user_id,email_enabled) values('{owner}',true) on conflict(user_id) do update set email_enabled=true;
insert into public.notifications(id,user_id,type,title,body) values('{notification}','{owner}','system','Synthetic HTTP notice','No external recipient');
update private.payment_sandbox_config set enabled=true;commit;""")
        now=datetime.now(timezone.utc)
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
        assert request('/notifications',{}, {'x-rad-local-test-token':'wrong'})[0]==403
        code,dispatch=request('/notifications',{}, {'x-rad-local-test-token':test_token})
        assert code==200 and dispatch['mode']=='sandbox' and dispatch['sandbox_receipts']==1
        assert sql(f"select to_json(status) from public.notification_deliveries where id='{delivery['delivery_id']}';")=='sandbox_delivered'
        assert request('/notifications',{}, {'x-rad-local-test-token':test_token})[1]['sandbox_receipts']==0
        after=sql("select to_json(md5(coalesce(jsonb_agg(to_jsonb(e) order by id)::text,'[]'))) from public.ai_entitlements e;")
        assert before==after,'HTTP sandbox changed canonical entitlements'
        report.update(status='PASS',payment_retry_requests=16,payment_insert_winners=1,forged_signature_denied=True,stale_signature_denied=True,
          delayed_event_ignored=True,terminal_subscription_not_reactivated=True,notification_sandbox_receipts=1,notification_replay_receipts=0,
          canonical_entitlements_unchanged=True)
    finally:
        try:
            sql(f"begin;set local request.jwt.claims='{{\"role\":\"service_role\"}}';delete from auth.users where id='{owner}';update private.payment_sandbox_config set enabled={'true' if original else 'false'};commit;")
        finally:
            process.terminate()
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
