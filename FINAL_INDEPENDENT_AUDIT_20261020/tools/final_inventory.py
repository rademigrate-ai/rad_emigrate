import concurrent.futures, datetime, hashlib, json, pathlib, subprocess

ROOT = pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate')
REPO = ROOT / 'rad_core_security_final'
OUT = ROOT / '_final_independent_evidence_20261020'
OUT.mkdir(exist_ok=True)
def git(*args, cwd=REPO):
    p = subprocess.run(['git', *args], cwd=cwd, text=True, encoding='utf-8', errors='replace', capture_output=True)
    return {'exit_code': p.returncode, 'output': p.stdout.strip(), 'error': p.stderr.strip()}
raw = git('worktree', 'list', '--porcelain')['output']
trees = []
for block in raw.split('\n\n'):
    d = dict(line.split(' ', 1) if ' ' in line else (line, True) for line in block.splitlines())
    if 'worktree' in d: trees.append(d)
def inspect(d):
    path = pathlib.Path(d['worktree'])
    d['status'] = git('status', '--porcelain=v1', '--untracked-files=normal', cwd=path)
    d['tracking'] = git('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}', cwd=path)
    if d['tracking']['exit_code'] == 0:
        d['ahead_behind'] = git('rev-list', '--left-right', '--count', 'HEAD...@{upstream}', cwd=path)
    d['last_commit'] = git('log', '-1', '--format=%H%n%aI%n%s', cwd=path)
    d['owner_basis'] = 'Name/branch attribution only; no live agent ownership channel verified'
    return d
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    trees = list(pool.map(inspect, trees))
refs = ['feat/rad-core-security-final','feat/rad-backend-services-final','feat/rad-unified-release-candidate','integration/antigravity-grok-a003-unified','feat/rad-new-features-ui','feat/antigravity-a003-flutter-implementation','integration/grok-final-unified-rc','feat/antigravity-flutter-e2e-completion','feat/grok-independent-feature-completion']
commits = ['9736540','24b3f6b','a24f492','c57b56d','b485c0c','e80f106','2e0d089','a9969c1','c710893','843ea7c','b97c8f0']
branches = []
for ref in refs:
    local = git('rev-parse', ref)
    remote = git('rev-parse', 'refs/remotes/origin/' + ref)
    row = {'branch':ref, 'local':local, 'remote':remote, 'ancestry':{}}
    if local['exit_code']==0:
        for commit in commits:
            row['ancestry'][commit] = git('merge-base','--is-ancestor',commit,ref)['exit_code']==0
        row['migration_count'] = len(git('ls-tree','-r','--name-only',ref,'supabase/migrations')['output'].splitlines())
    branches.append(row)
report = {'captured_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'candidate_sha':'1fe44f63d179263c5e719578bf7ebad0e17868d1','worktrees':trees,'branches':branches,'mutations':'None to inspected worktrees; git fetch updates remote refs only'}
(OUT/'inventory.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'evidence':str(OUT/'inventory.json'),'worktree_count':len(trees),'dirty':[{ 'path':x['worktree'],'status':x['status']['output']} for x in trees if x['status']['output']], 'branches':[{ 'branch':x['branch'],'sha':x['local']['output'],'remote':x['remote']['output'],'included':[k for k,v in x['ancestry'].items() if v]} for x in branches]},indent=2))
