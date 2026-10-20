"""Independently inspect location-only scanner findings; never print values."""
import collections,hashlib,json,pathlib,re,subprocess,uuid,sys
BASE=next(p for p in pathlib.Path(__file__).resolve().parents if (p/'rad_final_security_remediation').is_dir() and (p/'_security_remediation_20261020').is_dir())
ROOT=BASE/'rad_final_security_remediation';OUT=BASE/'_security_remediation_20261020'
prefix='b01_' if sys.argv[1:]==['b01'] else ''
if prefix:ROOT=BASE/'rad_security_verify_b01f625'
scan=json.loads((OUT/(prefix+'secret_scan.json')).read_text())
rows=[]
for scope,item in scan['scans'].items():
 for loc in item['locations']:
  file=loc['File'].removeprefix('/scan/');commit=loc.get('Commit') or scan['scan_revision']
  content=subprocess.check_output(['git','show',commit+':'+file],cwd=ROOT).decode('utf-8')
  lines=content.splitlines();line=lines[loc['StartLine']-1]
  row={'scope':scope,'file':file,'line':loc['StartLine'],'commit':commit,'rule':loc['RuleID']}
  valid=False
  if file.startswith('docs/releases/'):
   digest=re.search(r'"([a-f0-9]{64})"',line)
   filename=re.search(r'([0-9]{14}_[a-z0-9_]+\.sql)','\n'.join(reversed(lines[max(0,loc['StartLine']-7):loc['StartLine']])))
   if digest and filename:
    blob=subprocess.run(['git','show',commit+':supabase/migrations/'+filename[1]],cwd=ROOT,capture_output=True)
    variants=[blob.stdout,blob.stdout.replace(b'\r\n',b'\n'),blob.stdout.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')]
    valid=blob.returncode==0 and digest[1] in {hashlib.sha256(x).hexdigest() for x in variants}
   row.update(classification='migration_SQL_SHA256_metadata',source_digest_match=valid)
  elif file=='lib/core/services/ai/ai_guest_identity.dart':
   valid=bool(re.search(r'const.*[Kk]ey.*=.*[\'\"]rad_',line));row['classification']='constant_preference_key_identifier'
  elif file=='graphify-out/cache/stat-index.json':
   obj=json.loads(content)
   numeric={'size','mtime_ns','indexed_at_ns','word_count'}
   valid=isinstance(obj,dict) and all(isinstance(k,str) and isinstance(v,dict) and numeric<=set(v)<=numeric|{'hashes'} and all(isinstance(v[n],int) for n in numeric) and ('hashes' not in v or (isinstance(v['hashes'],dict) and all(hk==k.lower() and isinstance(hv,str) and re.fullmatch('[a-f0-9]{64}',hv) for hk,hv in v['hashes'].items()))) for k,v in obj.items())
   row.update(classification='repository_file_stat_cache',numeric_metadata_and_path_keyed_sha256_only=valid)
  elif file=='supabase/contracts/fixtures/rad_v1_synthetic.json':
   found=re.fullmatch(r'\s*"request_key": "([a-f0-9-]{36})",?\s*',line)
   obj=json.loads(content)
   valid=bool(found and str(uuid.UUID(found[1]))==found[1] and uuid.UUID(found[1]).version==4)
   valid=valid and isinstance(obj,list) and all(isinstance(v,dict) and {'name','request','response'}<=set(v) for v in obj)
   producer=subprocess.check_output(['git','show',commit+':scripts/rad_wire_acceptance.py'],cwd=ROOT).decode()
   valid=valid and 'rad_v1_synthetic.json' in producer and 'synthetic' in producer.lower()
   row.update(classification='synthetic_fixture_request_idempotency_UUID',uuid_format_valid=bool(found),producer_is_synthetic=True)
  else:row['classification']='UNREVIEWED'
  row['reviewed_noncredential']=valid;rows.append(row)
report={'candidate_sha':scan['scan_revision'],'automated_status':scan['status'],'review_status':'PASS' if all(r['reviewed_noncredential'] for r in rows) else 'REVIEW_REQUIRED','locations_reviewed':len(rows),'method':'Exact Git blobs at scan revision/history commits; SQL digest equality across LF/CRLF; strict stat-cache schema limited to numeric metadata and path-keyed SHA256 strings; constant identifier; UUID format plus synthetic fixture producer. No values emitted.','policy_changes':False,'secret_values_exported':False,'results':rows}
(OUT/(prefix+'secret_scan_review.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'review_status':report['review_status'],'classifications':dict(collections.Counter(r['classification'] for r in rows)),'unresolved':[r for r in rows if not r['reviewed_noncredential']]},indent=2))
