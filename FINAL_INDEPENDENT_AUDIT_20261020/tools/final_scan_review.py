"""Review scanner locations without emitting matched text or values."""
import hashlib,json,pathlib,re,subprocess
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate')
ROOT=BASE/'rad_final_independent_audit';OUT=BASE/'_final_independent_evidence_20261020'
scan=json.loads((OUT/'secret_scan.json').read_text())
rows=[]
for scope,item in scan['scans'].items():
    for loc in item['locations']:
        file=loc['File'].removeprefix('/scan/');commit=loc.get('Commit') or scan['scan_revision']
        p=subprocess.run(['git','show',commit+':'+file],cwd=ROOT,capture_output=True)
        assert p.returncode==0
        content=p.stdout.decode('utf-8');lines=content.splitlines();line=lines[loc['StartLine']-1]
        row={'scope':scope,'file':file,'line':loc['StartLine'],'commit':commit,'rule':loc['RuleID']}
        if file.startswith('docs/releases/'):
            digest=re.search(r'"([a-f0-9]{64})"',line)
            filename=re.search(r'([0-9]{14}_[a-z0-9_]+\.sql)', line)
            if filename is None:
                filename=re.search(r'([0-9]{14}_[a-z0-9_]+\.sql)', '\n'.join(reversed(lines[max(0,loc['StartLine']-7):loc['StartLine']])))
            row['classification']='migration_SQL_SHA256_metadata'
            row['format_valid']=bool(digest and filename)
            verified=False
            if digest and filename:
                blob=subprocess.run(['git','show',commit+':supabase/migrations/'+filename[1]],cwd=ROOT,capture_output=True)
                if blob.returncode==0:
                    variants=[blob.stdout,blob.stdout.replace(b'\r\n',b'\n'),blob.stdout.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')]
                    verified=digest[1] in {hashlib.sha256(x).hexdigest() for x in variants}
            row['source_digest_match']=verified
            row['reviewed_noncredential']=verified
        elif file=='lib/core/services/ai/ai_guest_identity.dart':
            row['classification']='constant_preference_key_identifier';row['reviewed_noncredential']=bool(re.search(r'const.*[Kk]ey.*=.*[\'\"]rad_',line))
        elif file=='graphify-out/cache/stat-index.json':
            obj=json.loads(content)
            def valid(x):
                if isinstance(x,dict):return all(valid(v) for v in x.values())
                if isinstance(x,list):return all(valid(v) for v in x)
                return isinstance(x,(str,int,float,bool)) or x is None
            row['classification']='repository_stat_index_cache';row['valid_json']=valid(obj)
            row['reviewed_noncredential']=valid(obj) and all(not re.search(r'eyJ[A-Za-z0-9_-]{20,}\.',str(x)) for x in obj)
        else:row['classification']='UNREVIEWED';row['reviewed_noncredential']=False
        rows.append(row)
report={'candidate_sha':scan['scan_revision'],'automated_status':scan['status'],'review_status':'PASS' if all(r['reviewed_noncredential'] for r in rows) else 'REVIEW_REQUIRED','locations_reviewed':len(rows),'policy_changes':False,'secret_values_exported':False,'results':rows}
(OUT/'secret_scan_review.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'review_status':report['review_status'],'locations':len(rows),'unresolved':[r for r in rows if not r['reviewed_noncredential']]},indent=2))
