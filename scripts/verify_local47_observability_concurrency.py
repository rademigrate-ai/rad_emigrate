#!/usr/bin/env python3
"""Race optional local health alerts and recovery; no external monitor/transport."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--psql', required=True, type=Path)
    parser.add_argument('--report', required=True, type=Path)
    args = parser.parse_args()
    project = os.environ.get('RAD_LOCAL47_PROJECT', 'rad_codex_local47')
    port = int(os.environ.get('RAD_LOCAL47_PORT', '55322'))
    runtime = Path(os.environ.get('TEMP', '/tmp'))/project
    assert json.loads((runtime/'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text(encoding='utf-8')) == {
        'project':project,'source':str(ROOT),'port':port}, 'wrong runtime owner'
    env = os.environ.copy()
    env['PGPASSWORD'] = 'postgres'
    command = [str(args.psql.resolve()), '-XqAt', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1', '-p', str(port), '-U', 'postgres', '-d', 'postgres']

    def sql(source, elevated=False):
        role = 'set local role service_role;' if elevated else ''
        result = subprocess.run(command, input="begin;set local request.jwt.claims='{\"role\":\"service_role\"}';"+role+source+';commit;',
            env=env, capture_output=True, text=True, encoding='utf-8', timeout=30)
        assert result.returncode == 0, 'synthetic observability SQL failed'
        lines = [line for line in result.stdout.splitlines() if line.strip()]
        return json.loads(lines[-1]) if lines else None

    slug = 'local47_'+uuid.uuid4().hex
    original = sql('select row_to_json(p) from private.health_alert_policy p where singleton')
    report = {'scope':'owned_local_health_alert_parallel_sessions','production_mutations':False,'external_alerts_sent':0,
        'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'source_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip()),
        'captured_at':datetime.now(timezone.utc).isoformat()}
    try:
        sql(f"insert into public.system_components(slug,display_name,critical) values('{slug}','Synthetic health race',true);"
            "update private.health_alert_policy set enabled=true,consecutive_samples=2 where singleton")
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda _: sql(f"select public.record_component_health('{slug}','offline',12,'synthetic_failure')", elevated=True), range(32)))
        incidents = sql(f"select json_agg(json_build_object('id',id,'status',status,'severity',severity)) from public.incidents where component_slug='{slug}'")
        assert len(incidents)==1 and incidents[0]['status']=='investigating' and incidents[0]['severity']=='critical', 'duplicate or missing concurrent incident'
        incident = incidents[0]['id']
        assert sql(f"select to_json(count(*)) from public.operational_events where component_slug='{slug}' and event_type='component.health_alert'") == 1
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda _: sql(f"select public.record_component_health('{slug}','healthy',3,'ok')", elevated=True), range(20)))
        assert sql(f"select to_json(status) from public.incidents where id='{incident}'") == 'monitoring', 'recovery skipped human resolution'
        assert sql(f"select to_json(count(*)) from public.operational_events where component_slug='{slug}' and event_type='component.health_recovered'") == 1
        assert sql(f"select to_json(count(*)) from public.incident_events where incident_id='{incident}'") == 2
        # Unknown observations break consecutive failure samples without resolving.
        sql(f"select public.record_component_health('{slug}','offline',1,'synthetic_failure');"
            f"select public.record_component_health('{slug}','unknown',null,null);"
            f"select public.record_component_health('{slug}','offline',1,'synthetic_failure')", elevated=True)
        assert sql(f"select to_json(status) from public.incidents where id='{incident}'") == 'monitoring'
        sql(f"select public.record_component_health('{slug}','offline',1,'synthetic_failure')", elevated=True)
        assert sql(f"select to_json(status) from public.incidents where id='{incident}'") == 'investigating'
        assert sql(f"select to_json(count(*)) from public.incidents where component_slug='{slug}'") == 1
        report.update(status='PASS', concurrent_failure_samples=32, incident_count=1, opening_alert_count=1,
            concurrent_healthy_samples=20, recovery_event_count=1, recovery_requires_human_resolution=True,
            unknown_breaks_consecutive_samples=True, relapse_reuses_existing_incident=True)
    finally:
        sql(f"update private.health_alert_policy set enabled={'true' if original['enabled'] else 'false'},consecutive_samples={int(original['consecutive_samples'])} where singleton;"
            f"delete from public.operational_events where component_slug='{slug}';"
            f"delete from public.incidents where component_slug='{slug}';"
            f"delete from public.system_components where slug='{slug}'")
    report['original_alert_policy_restored'] = True
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
