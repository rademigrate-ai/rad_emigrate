"""Compare all captured catalogs; emit explicit, bounded drift diagnostics."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
expected = json.loads((root / 'supabase/reconciliation/production_catalog.json').read_text())
actual = json.loads(Path(sys.argv[1]).read_text())
report = {}
blocking = False

def normalize(key, rows):
    rows = json.loads(json.dumps(rows))
    for row in rows:
        # ACL ordering has no meaning in Postgres.
        for field in ('acl', 'nspacl', 'defaclacl'):
            if isinstance(row.get(field), str):
                row[field] = sorted(row[field].strip('{}').split(','))
        if key == 'cron':
            row.pop('jobid', None)
        if key == 'extensions':
            row.pop('extversion', None)
    return sorted(rows, key=lambda r: json.dumps(r, sort_keys=True))

for key in sorted(expected):
    if key not in actual:
        report[key] = {'status': 'UNKNOWN', 'reason': 'missing actual group'}
        blocking = True
        continue
    lhs, rhs = normalize(key, expected[key]), normalize(key, actual[key])
    if lhs == rhs:
        status = 'MATCH' if expected[key] == actual[key] else 'EXPECTED ENVIRONMENT DIFFERENCE'
        report[key] = {'status': status, 'rows': len(rhs)}
    elif key == 'vault_metadata' and rhs == []:
        # The isolated database intentionally has no production project secrets.
        report[key] = {'status': 'EXPECTED ENVIRONMENT DIFFERENCE',
                       'reason': 'production secret names only; isolated Vault empty'}
    else:
        security = key in ('rls', 'policies', 'functions', 'function_grants',
                           'triggers', 'table_grants', 'column_grants', 'table_acl',
                           'default_acl', 'schemas', 'buckets', 'vault_client_access')
        missing = [r for r in lhs if r not in rhs]
        extra = [r for r in rhs if r not in lhs]
        report[key] = {'status': 'SECURITY-RELEVANT DRIFT' if security else 'FUNCTIONAL DRIFT',
                       'missing_count': len(missing), 'extra_count': len(extra),
                       'missing': missing, 'extra': extra}
        blocking = True
        print(f'  missing={len(missing)} extra={len(extra)}')
        for label, differences in [('missing', missing), ('extra', extra)]:
            for row in differences[:3]:
                print(f'  {label}: {json.dumps(row, sort_keys=True)[:1400]}')
    print(f'{key}: {report[key]["status"]}')

Path('reconciliation-report.json').write_text(json.dumps(report, indent=2) + '\n')
raise SystemExit(1 if blocking else 0)
