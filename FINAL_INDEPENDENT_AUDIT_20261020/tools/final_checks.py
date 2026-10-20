import concurrent.futures, datetime, hashlib, json, os, pathlib, subprocess, sys, time

ROOT=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate\rad_final_independent_audit')
OUT=ROOT.parent/'_final_independent_evidence_20261020'
SHA='1fe44f63d179263c5e719578bf7ebad0e17868d1'
ENV={**os.environ,'CI':'true','NO_PROXY':'localhost,127.0.0.1'}
def run(name, command, timeout=2400):
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()==SHA
    before=time.monotonic(); now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    try:
        with (OUT/(name+'.log')).open('w',encoding='utf-8') as log:
            p=subprocess.run(command,cwd=ROOT,env=ENV,stdout=log,stderr=subprocess.STDOUT,timeout=timeout,shell=isinstance(command,str))
        code=p.returncode; error=None
    except subprocess.TimeoutExpired:code=None;error='TIMEOUT'
    except OSError as e:code=None;error=type(e).__name__
    path=OUT/(name+'.log')
    result={'name':name,'candidate_sha':SHA,'command':command,'started_at':now,'duration_seconds':round(time.monotonic()-before,2),'exit_code':code,'error':error,'log':str(path),'log_sha256':hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None}
    (OUT/(name+'.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result),flush=True)
    return code
def flutter():
    if run('flutter_pub_get','flutter pub get')!=0:return
    run('dart_format','dart format --output=none --set-exit-if-changed lib test')
    run('flutter_analyze','flutter analyze --no-pub')
    run('flutter_test','flutter test --no-pub --reporter expanded')
    run('web_build','flutter build web --release --no-pub --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder')
    run('android_debug','flutter build apk --debug --no-pub --target-platform android-arm64 --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder')
def backend():
    deno=str(pathlib.Path.home()/'.deno/bin/deno.exe')
    run('deno_version',[deno,'--version'])
    run('deno_lint',[deno,'lint','supabase/functions'])
    run('deno_test',[deno,'test','--allow-env','supabase/functions/tests'])
    run('python_tests',[sys.executable,'-m','unittest','discover','-s','scripts/tests','-v'])
    run('recovery_redirect',['node','scripts/check_password_recovery_redirect.cjs'])
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    for f in [pool.submit(flutter),pool.submit(backend)]:f.result()
