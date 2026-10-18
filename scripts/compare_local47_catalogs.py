#!/usr/bin/env python3
"""Compare canonical and reconstructed metadata on the two owned local stacks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[1]


def normalize(group, rows):
    rows=json.loads(json.dumps(rows))
    for row in rows:
        for field in ('acl','nspacl','defaclacl'):
            if isinstance(row.get(field),str):row[field]=sorted(row[field].strip('{}').split(','))
        if group=='cron':row.pop('jobid',None)
    return sorted(rows,key=lambda row:json.dumps(row,sort_keys=True))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--psql',required=True,type=Path)
    parser.add_argument('--report',required=True,type=Path)
    args=parser.parse_args()
    env=os.environ.copy();env['PGPASSWORD']='postgres'
    catalogs=[]
    for port in (55322,57322):
        result=subprocess.run([str(args.psql.resolve()),'-XAt','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(port),
          '-U','postgres','-d','postgres','-f',str(ROOT/'supabase/reconciliation/catalog_fingerprint.sql')],
          capture_output=True,text=True,encoding='utf-8',env=env,check=True)
        catalogs.append(json.loads(result.stdout))
    report={'scope':'two_disposable_loopback_catalogs','production_mutations':False,'groups':{}}
    failed=False
    for group in sorted(set(catalogs[0])|set(catalogs[1])):
        left,right=[normalize(group,catalog.get(group,[])) for catalog in catalogs]
        if group=='history':
            report['groups'][group]={'status':'EXPECTED_REPLAY_METHOD_DIFFERENCE','canonical_versions':len(left),'historical_versions':len(right)}
            assert len(right)==25,'historical replay no longer has the 25-version captured baseline'
            continue
        matching=left==right
        report['groups'][group]={'status':'MATCH' if matching else 'DRIFT','canonical_rows':len(left),'reconstructed_rows':len(right)}
        if not matching:
            failed=True
            report['groups'][group].update(missing=[r for r in left if r not in right],extra=[r for r in right if r not in left])
    report['status']='FAIL' if failed else 'PASS'
    report['catalog_sha256']=[hashlib.sha256(json.dumps(c,sort_keys=True).encode()).hexdigest() for c in catalogs]
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))
    if failed:raise SystemExit(1)


if __name__=='__main__':main()
