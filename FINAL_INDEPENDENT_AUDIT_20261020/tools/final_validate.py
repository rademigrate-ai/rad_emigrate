import hashlib,json,pathlib,re,subprocess
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate');ROOT=BASE/'rad_final_independent_audit';RAW=BASE/'_final_independent_evidence_20261020';OUT=ROOT/'FINAL_INDEPENDENT_AUDIT_20261020';E=OUT/'evidence'
SHA='1fe44f63d179263c5e719578bf7ebad0e17868d1'
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
assert git('rev-parse','HEAD').decode().strip()==SHA
generated=['linux/flutter/generated_plugin_registrant.cc','linux/flutter/generated_plugin_registrant.h','linux/flutter/generated_plugins.cmake','macos/Flutter/GeneratedPluginRegistrant.swift','windows/flutter/generated_plugin_registrant.cc','windows/flutter/generated_plugin_registrant.h','windows/flutter/generated_plugins.cmake']
changes=git('diff','--name-only').decode().splitlines();assert set(changes)<=set(generated),changes
for rel in changes:assert (ROOT/rel).read_bytes().replace(b'\r\n',b'\n')==git('show','HEAD:'+rel).replace(b'\r\n',b'\n'),rel
if changes:subprocess.run(['git','restore','--source=HEAD','--',*changes],cwd=ROOT,check=True)
assert git('diff','--name-only').decode().strip()==''
def read(name):return json.loads((E/name).read_text(encoding='utf-8-sig'))
def log(name):
    b=(RAW/name).read_bytes()
    return b.decode('utf-16') if b.startswith((b'\xff\xfe',b'\xfe\xff')) else b.decode('utf-8-sig',errors='replace')
for name in ['dart_format','flutter_analyze','web_build','android_debug','python_tests','recovery_redirect']:assert read(name+'.json')['exit_code']==0,name
assert read('flutter_test.json')['exit_code']==1
assert '+834 -1: Some tests failed' in log('flutter_test.log')
assert '132 passed | 0 failed' in log('deno_read_scope.log')
assert '+0 -3: Some tests failed' in log('runtime_fallback_probe.log')
assert read('runtime_fallback_probe.json')['failed']==3
assert read('edge_http.json')['status']=='PASS'
assert len(read('canonical_http_acceptance.json')['checks'])==28
assert len(read('canonical_canonical_report.json')['applied_manifest'])==72
assert len(read('upgrade_upgrade_report.json')['applied_manifest'])==12
assert read('upgrade_compare_report.json')['status']=='PASS'
assert read('upgrade_compare_report.json')['zero_historical_pending']
assert all(r['equal'] for r in read('migration_reconciliation.json')['historical_metadata_comparison'].values())
assert len(read('ci_status.json')['jobs'])==7
assert sum(r['conclusion']=='failure' for r in read('ci_status.json')['jobs'])==4
assert read('secret_scan_review.json')['review_status']=='PASS'
assert read('secret_scan.json')['status']=='FINDINGS_REQUIRE_REVIEW'
for item in read('migration_reconciliation.json')['manifest']:
    b=(ROOT/'supabase/migrations'/item['name']).read_bytes()
    assert hashlib.sha256(b).hexdigest()==item['sha256']
    assert hashlib.sha256(git('show',SHA+':supabase/migrations/'+item['name'])).hexdigest()==item['git_lf_sha256']
for path in E.glob('artifact_*.json'):
    r=json.loads(path.read_text());assert hashlib.sha256((ROOT/r['file']).read_bytes()).hexdigest()==r['sha256']
docs=list(OUT.glob('*.md'));assert len(docs)==8
for p in docs:
    assert 'NOT COMPLETE' not in p.read_text(),p
report={'status':'PASS','candidate_sha':SHA,'application_migration_files_changed':False,'restored_own_generated_files_only':changes,'checks':['Exact candidate SHA','Only generated EOL noise restored in owned checkout','Local build exits and actual full-suite failure','132 scoped Deno passes','3 additional fallback regression failures','28 real Auth HTTP checks','72 clean / 12 additive replay files','Fresh hosted metadata parity across 11 dimensions','7 CI jobs / 4 failures retained','Gitleaks automated findings separate from manual review','Every migration replay digest matches original Git source after LF normalization','Local artifact digests','8 complete audit documents']}
(E/'audit_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report,indent=2))
