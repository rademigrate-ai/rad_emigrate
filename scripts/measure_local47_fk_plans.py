#!/usr/bin/env python3
"""Measure three FK indexes on synthetic rows in a rollback-only local transaction.

No planner switches are forced. The counterfactual drops only these indexes in
the same disposable transaction, then ROLLBACK restores schema and fixtures.
These measurements are not a Production load benchmark or SLO.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import uuid
from datetime import datetime, timezone

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--psql',required=True,type=Path)
    parser.add_argument('--report',required=True,type=Path)
    args=parser.parse_args()
    runtime=Path(os.environ.get('TEMP','/tmp'))/'rad_codex_local47_reconstruct_57322'
    marker=json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text(encoding='utf-8'))
    assert marker=={'project':'rad_codex_local47_reconstruct','source':str(ROOT),'port':57322},'wrong local runtime owner'
    owner,admin,application,item,target=[str(uuid.uuid4()) for _ in range(5)]
    indexes=['knowledge_claims_superseded_by_idx','consultation_requests_assigned_to_idx','consultation_requests_related_application_id_idx']
    queries=[f"select id from public.knowledge_claims where superseded_by='{target}'::uuid",
      f"select id from public.consultation_requests where assigned_to='{admin}'::uuid",
      f"select id from public.consultation_requests where related_application_id='{application}'::uuid"]
    source=f"""begin;
set local request.jwt.claims='{{"role":"service_role"}}';
insert into auth.users(id,email,raw_user_meta_data) values('{owner}','{owner}@example.invalid','{{}}'),('{admin}','{admin}@example.invalid','{{}}');
update public.profiles set role='admin' where id='{admin}';
set local request.jwt.claims='{{"role":"authenticated","sub":"{admin}"}}';
set local request.jwt.claim.sub='{admin}';
insert into public.applications(id,user_id,visa_type) values('{application}','{owner}','synthetic fixture');
insert into public.consultation_requests(user_id,topic,message,assigned_to,related_application_id)
 select '{owner}','Synthetic FK fixture','No real person or policy',case when i%100=0 then '{admin}'::uuid end,
 case when i%100=0 then '{application}'::uuid end from generate_series(1,10000) i;
insert into public.knowledge_items(id,slug,language_code,title,summary,review_status)
 values('{item}','synthetic-{item}','en','Synthetic FK fixture','No factual policy assertions','draft');
insert into public.knowledge_claims(id,knowledge_item_id,claim_text,claim_key)
 values('{target}','{item}','Synthetic target','synthetic-target');
insert into public.knowledge_claims(knowledge_item_id,claim_text,claim_key,is_current,superseded_by,review_status)
 select '{item}','Synthetic claim '||i,'synthetic-'||i,i%200<>0,case when i%200=0 then '{target}'::uuid end,
 case when i%200=0 then 'superseded' else 'unreviewed' end from generate_series(1,20000) i;
analyze public.consultation_requests; analyze public.knowledge_claims;
"""
    source+='\n'.join('explain (analyze,buffers,format json) '+query+';' for query in queries)
    source+='\n'+'\n'.join('drop index public.'+name+';' for name in indexes)+'\n'
    source+='\n'.join('explain (analyze,buffers,format json) '+query+';' for query in queries)+'\nrollback;'
    env=os.environ.copy();env['PGPASSWORD']='postgres'
    command=[str(args.psql.resolve()),'-XqAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p','57322','-U','postgres','-d','postgres']
    result=subprocess.run(command,input=source,env=env,capture_output=True,text=True,encoding='utf-8',check=True,timeout=120)
    remaining=result.stdout.strip();plans=[];decoder=json.JSONDecoder()
    while remaining:
        plan,end=decoder.raw_decode(remaining);plans.append(plan[0]);remaining=remaining[end:].strip()
    assert len(plans)==6,'expected indexed and unindexed plans for three probes'
    def nodes(plan):
        found=[plan]
        for child in plan.get('Plans',[]):found+=nodes(child)
        return found
    report={'scope':'synthetic_local_57322','production_mutations':False,'transaction_rolled_back':True,
      'planner_switches_forced':False,'fixture_consultations':10000,'fixture_claims':20001,'probes':[]}
    report.update(captured_at=datetime.now(timezone.utc).isoformat(),
      source_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
      source_dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip()))
    for index,before,after in zip(indexes,plans[:3],plans[3:]):
        before_nodes=nodes(before['Plan']);after_nodes=nodes(after['Plan'])
        used=[node['Index Name'] for node in before_nodes if 'Index Name' in node]
        assert index in used,f'planner did not choose {index}'
        assert any(node['Node Type']=='Seq Scan' for node in after_nodes),'counterfactual was not a sequential scan'
        assert before['Plan']['Actual Rows']==after['Plan']['Actual Rows']==100,'probe result cardinality differs'
        report['probes'].append({'index':index,'indexed_nodes':[node['Node Type'] for node in before_nodes],
          'without_index_nodes':[node['Node Type'] for node in after_nodes],'actual_rows':100,
          'indexed_execution_ms':before['Execution Time'],'without_index_execution_ms':after['Execution Time']})
    restored=subprocess.run(command,input="select count(*) from pg_indexes where schemaname='public' and indexname in ("+
      ','.join("'"+name+"'" for name in indexes)+");",env=env,capture_output=True,text=True,encoding='utf-8',check=True)
    assert restored.stdout.strip()=='3','rollback did not restore the three indexes'
    report['status']='PASS'
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
