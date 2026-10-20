import hashlib, json, pathlib, subprocess
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate')
OUT=BASE/'_security_remediation_20261020'
old=json.loads((BASE/'_audit/C002_C003_20261019/evidence/prod_catalog.json').read_text(encoding='utf-8'))
current=json.loads((OUT/'hosted_catalog_metadata.json').read_text(encoding='utf-8'))
def canonical(rows,dim):
    rows=json.loads(json.dumps(rows))
    if dim=='column_grants':
        rows=[{**{k:v for k,v in r.items() if k!='columns'},'column_name':name} for r in rows for name in r.get('columns',[r.get('column_name')])]
    if dim=='functions':
        for r in rows:r.pop('definition',None)
    if dim=='default_grants':
        for r in rows:
            acl=r['acl']
            r['acl']=sorted(acl.strip('{}').split(',')) if isinstance(acl,str) else sorted(acl or [])
    if dim=='policies':
        for r in rows:
            if isinstance(r['roles'],str):r['roles']=r['roles'].strip('{}').split(',')
    return sorted(set(json.dumps(r,sort_keys=True,ensure_ascii=False) for r in rows))
comparison={}
for dim,rows in current.items():
    before=set(canonical(old.get(dim,[]),dim));after=set(canonical(rows,dim))
    comparison[dim]={'before_rows':len(before),'current_rows':len(after),'equal':before==after,'removed_count':len(before-after),'added_count':len(after-before)}
    if before!=after:
        (OUT/('catalog_drift_'+dim+'.json')).write_text(json.dumps({'removed':[json.loads(r) for r in sorted(before-after)],'added':[json.loads(r) for r in sorted(after-before)]},indent=2,ensure_ascii=False),encoding='utf-8')
host=json.loads((OUT/'hosted_snapshot.json').read_text(encoding='utf-8'))
ledger={r['version']:r for r in host['ledger']}
candidate=BASE/'rad_final_security_remediation'
manifest=[{'version':p.name.split('_')[0],'name':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'git_lf_sha256':hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()} for p in sorted((candidate/'supabase/migrations').glob('*.sql'))]
versions={r['version'] for r in manifest}
result={'project_id':'inshddthftkhcdosoqcn','captured_at':host['captured_at'],'source_candidate_sha':subprocess.check_output(['git','rev-parse','HEAD'],cwd=candidate,text=True).strip(),'historical_metadata_comparison':comparison,'scope':'Metadata only, no business rows, credentials or Vault values','candidate_migration_count':len(manifest),'hosted_ledger_count':len(ledger),'repo_only':[r for r in manifest if r['version'] not in ledger],'hosted_only':[r for k,r in ledger.items() if k not in versions],'manifest':manifest}
(OUT/'migration_reconciliation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ('manifest','repo_only')}|{'repo_only_versions':[r['version'] for r in result['repo_only']]},indent=2))
