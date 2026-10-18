#!/usr/bin/env python3
"""Prepare a target-bound deployment/rollback plan. Never executes cloud commands."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from staging_environment import StagingConfigError, read_environment_file, validate_staging

ROOT=Path(__file__).resolve().parents[1]


def prepare_plan(values: dict[str,str], revision: str, migrations: list[dict], functions: list[str]) -> dict:
    target=validate_staging(values,public_build=False)
    if len(revision)!=40 or any(char not in '0123456789abcdef' for char in revision):
        raise StagingConfigError('immutable_source_revision_required')
    project=target['project_ref']
    blocked=[]
    if not target['database_connection_configured']: blocked.append('staging_database_connection')
    if not values.get('RAD_STAGING_BACKUP_RECORD'): blocked.append('verified_staging_backup_and_restore_record')
    if not values.get('RAD_STAGING_ROLLBACK_RELEASE'): blocked.append('approved_previous_release_or_first_deploy_rollback_artifact')
    blocked.extend(['explicit_staging_deployment_authorization','real_staging_auth_storage_smoke','provider_specific_activation_approval'])
    # These argv descriptions contain environment references, never key values.
    # They are review material only; no subprocess runs these commands here.
    commands=[
        {'purpose':'target-bound migration preview','argv':['supabase','db','push','--db-url','${RAD_STAGING_DB_URL}','--dry-run']},
        {'purpose':'apply only after owner authorization and backup review','argv':['supabase','db','push','--db-url','${RAD_STAGING_DB_URL}']},
    ]
    eligible=[name for name in functions if name!='payment-sandbox']
    for name in eligible:
        commands.append({'purpose':'deploy only after owner authorization','argv':['supabase','functions','deploy',name,'--project-ref',project]})
    payload={'schema_version':1,'status':'PLAN_ONLY_NOT_DEPLOYED','source_revision':revision,
        'target':{'project_ref':project,'api_host':target['api_host'],'site_host':target['site_host']},
        'migrations':migrations,'edge_functions':eligible,
        'excluded_local_only_functions':[name for name in functions if name=='payment-sandbox'],
        'commands_for_owner_review':commands,'blocked_by_owner':blocked,
        'rollback':{'release_record_configured':bool(values.get('RAD_STAGING_ROLLBACK_RELEASE')),
            'backup_record_configured':bool(values.get('RAD_STAGING_BACKUP_RECORD')),
            'steps':['disable optional provider/worker activation in this isolated staging environment',
                'redeploy the owner-approved rollback web and function artifacts by immutable SHA',
                'retain compatible additive migrations; do not edit migration history',
                'if schema is incompatible, stop staging writes and use only the verified staging restore procedure and backup record',
                'rerun target checks, version/Auth/Storage/RLS smoke before re-enabling staging']},
        'production_mutations':False,'external_commands_executed':False,
        'key_binding_limit':target['public_key_binding']}
    payload['plan_sha256']=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    return payload


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env-file',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    try:
        values=read_environment_file(args.env_file)
        validate_staging(values,public_build=False)
        dirty=subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip()
        if dirty: raise StagingConfigError('clean_source_checkout_required')
        revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
        destination=args.output.resolve()
        if destination==ROOT or ROOT in destination.parents:
            raise StagingConfigError('plan_output_must_be_outside_checkout')
        paths=subprocess.check_output(['git','ls-tree','-r','--name-only',revision,'supabase/migrations'],cwd=ROOT,text=True).splitlines()
        migrations=[]
        for path in paths:
            content=subprocess.check_output(['git','show',revision+':'+path],cwd=ROOT)
            if path.endswith('.sql') and content.strip():
                migrations.append({'path':path,'sha256':hashlib.sha256(content.replace(b'\r\n',b'\n')).hexdigest()})
        functions=sorted(path.parent.name for path in (ROOT/'supabase/functions').glob('*/index.ts'))
        plan=prepare_plan(values,revision,migrations,functions)
        destination.parent.mkdir(parents=True,exist_ok=True)
        destination.write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8')
    except (StagingConfigError,OSError,subprocess.CalledProcessError) as error:
        code=str(error) if isinstance(error,StagingConfigError) else 'local_plan_preparation_failed'
        print(json.dumps({'status':'FAIL','error':code}),file=sys.stderr)
        return 2
    print(json.dumps({'status':plan['status'],'source_revision':revision,'project_ref':plan['target']['project_ref'],
        'migration_count':len(migrations),'plan_sha256':plan['plan_sha256'],'external_commands_executed':False}))
    return 0


if __name__=='__main__': raise SystemExit(main())
