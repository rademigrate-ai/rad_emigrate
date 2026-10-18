#!/usr/bin/env python3
"""Real concurrent sessions against Codex's dedicated loopback-only test stack."""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import uuid


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--psql',required=True,type=Path)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    env=os.environ.copy();env['PGPASSWORD']='postgres'
    port=int(os.environ.get('RAD_LOCAL47_PORT','55322'))
    command=[str(args.psql.resolve()),'-XqAt','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate',
             '-h','127.0.0.1','-p',str(port),'-U','postgres','-d','postgres']
    owner,admin,consultation=[str(uuid.uuid4()) for _ in range(3)]
    subscription='local47-'+uuid.uuid4().hex
    claim_service="begin; set local request.jwt.claims='{\"role\":\"service_role\"}'; set local request.jwt.claim.sub=''; set local role service_role;"
    def sql(source: str, conflict: bool=False):
        result=subprocess.run(command,input=source,env=env,text=True,encoding='utf-8',capture_output=True,timeout=60)
        if result.returncode:
            if conflict and '40001' in result.stderr: return None
            raise AssertionError('local concurrency SQL failed: '+result.stderr[-200:].replace('\n',' '))
        lines=[line for line in result.stdout.splitlines() if line.strip()]
        return json.loads(lines[-1]) if lines else None
    def service(statement: str): return sql(claim_service+statement+';commit;')
    report={'target':f'127.0.0.1:{port}','production_mutations':False,'mode':'synthetic_sandbox'}
    original_enabled=sql('select to_json(enabled) from private.payment_sandbox_config where singleton;')
    assert sql("select to_json(count(*)) from public.notification_deliveries where status in ('queued','processing');")==0, 'outbox has other pending work; refusing to consume it'
    before=sql("select to_json(md5(coalesce(jsonb_agg(to_jsonb(e) order by id)::text,'[]'))) from public.ai_entitlements e;")
    try:
        sql(f"""begin;
set local request.jwt.claims='{{"role":"service_role"}}';
insert into auth.users(id,email,raw_user_meta_data) values('{owner}','{owner}@example.invalid','{{}}'),('{admin}','{admin}@example.invalid','{{}}');
update public.profiles set role='admin' where id='{admin}';
insert into public.notification_preferences(user_id,email_enabled) values('{owner}',true) on conflict(user_id) do update set email_enabled=true;
insert into public.notifications(user_id,type,title,body) select '{owner}','system','Synthetic concurrency','No real recipient' from generate_series(1,12);
select count(public.queue_notification_delivery(id,'email')) from public.notifications where user_id='{owner}';
set local request.jwt.claims='{{"role":"authenticated","sub":"{owner}"}}';
set local request.jwt.claim.sub='{owner}'; set local role authenticated;
select to_json(public.submit_consultation_request('Synthetic race','Synthetic local-only request',null)); commit;""")
        # Owner only has one newly created request in this synthetic fixture.
        consultation=sql(f"select to_json(id) from public.consultation_requests where user_id='{owner}';")
        with ThreadPoolExecutor(max_workers=16) as pool:
            claims=list(pool.map(lambda _: service('select coalesce(jsonb_agg(jsonb_build_object(\'id\',d.id,\'token\',d.lease_token)),\'[]\') from public.claim_sandbox_notification() d'),range(32)))
        leases=[row for batch in claims for row in batch]
        assert len(leases)==12 and len({r['id'] for r in leases})==12, 'concurrent workers duplicated or lost a lease'
        with ThreadPoolExecutor(max_workers=16) as pool:
            acknowledgements=list(pool.map(lambda _: service(f"select to_json(public.finish_sandbox_notification('{leases[0]['id']}','{leases[0]['token']}',true))"),range(20)))
        assert acknowledgements.count(True)==1 and acknowledgements.count(False)==19, 'receipt acknowledgement was not at most once'
        def transition(_):
            return sql(f"begin; set local request.jwt.claims='{{\"role\":\"authenticated\",\"sub\":\"{admin}\"}}'; set local request.jwt.claim.sub='{admin}'; set local role authenticated; select public.transition_admin_consultation('{consultation}','in_review',1,null); commit;",True)
        with ThreadPoolExecutor(max_workers=16) as pool:
            transitions=list(pool.map(transition,range(20)))
        assert sum(value is not None for value in transitions)==1, 'optimistic CRM revision allowed more than one winner'
        assert sql(f"select to_json(revision) from public.consultation_requests where id='{consultation}';")==2
        sql('update private.payment_sandbox_config set enabled=true;')
        now=datetime.now(timezone.utc)
        payload={'mode':'sandbox','event_id':'event-'+uuid.uuid4().hex,'subscription_id':subscription,'user_id':owner,
                 'type':'payment_succeeded','sequence':1,'amount_minor':100,'currency':'TST',
                 'occurred_at':now.isoformat(),'period_end':(now+timedelta(days=1)).isoformat()}
        def payment(value):
            raw=json.dumps(value,separators=(',',':'))
            digest=hashlib.sha256(raw.encode()).hexdigest()
            # All interpolated content is generated above, not caller input.
            return service(f"select public.apply_sandbox_payment_event('{raw}'::jsonb,'{digest}')")
        with ThreadPoolExecutor(max_workers=16) as pool: duplicates=list(pool.map(lambda _:payment(payload),range(20)))
        assert sum(not value['duplicate'] for value in duplicates)==1
        assert sql(f"select to_json(count(*)) from public.sandbox_payment_events where subscription_id='{subscription}';")==1
        competing=[{**payload,'event_id':'race-'+uuid.uuid4().hex,'sequence':2} for _ in range(12)]
        competing.append({**payload,'event_id':'refund-'+uuid.uuid4().hex,'sequence':3,'type':'payment_refunded'})
        with ThreadPoolExecutor(max_workers=16) as pool: list(pool.map(payment,competing))
        assert sql(f"select to_json(status) from public.sandbox_payment_subscriptions where subscription_id='{subscription}';")=='refunded'
        after=sql("select to_json(md5(coalesce(jsonb_agg(to_jsonb(e) order by id)::text,'[]'))) from public.ai_entitlements e;")
        assert before==after, 'sandbox changed canonical AI entitlement data'
        report.update(status='PASS',outbox_requests=32,unique_leases=12,ack_requests=20,ack_winners=1,
                      crm_requests=20,crm_winners=1,payment_duplicate_requests=20,payment_insert_winners=1,
                      payment_refund_race_requests=13,final_sandbox_status='refunded',canonical_entitlements_unchanged=True)
    finally:
        sql(f"begin; set local request.jwt.claims='{{\"role\":\"service_role\"}}'; delete from auth.users where id in ('{owner}','{admin}'); update private.payment_sandbox_config set enabled={'true' if original_enabled else 'false'}; commit;")
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__': main()
