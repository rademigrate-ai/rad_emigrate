#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
backup="$(mktemp -d)/migrations"
mv supabase/migrations "$backup"
mkdir -p supabase/migrations
cleanup() {
  rm -rf supabase/migrations
  mv "$backup" supabase/migrations
  rmdir "$(dirname "$backup")"
  supabase stop --no-backup >/dev/null 2>&1 || true
}
trap cleanup EXIT
supabase --help >/dev/null
supabase migration up --help >/dev/null
supabase migration list --help >/dev/null
supabase db push --help >/dev/null
# Start without the product migration directory. Never link to production.
supabase start
cp supabase/reconciliation/candidate/*.sql supabase/migrations/
supabase migration up --local
psql "$DB_URL" -XAt -v ON_ERROR_STOP=1 \
  -f supabase/reconciliation/catalog_fingerprint.sql > reconstructed-catalog.json
# Do not mutate reconstructed metadata before equivalence verification.
python3 scripts/compare_reconciliation_catalog.py reconstructed-catalog.json
supabase migration list --db-url "$DB_URL" > reconstruction-migration-list.txt
supabase db push --db-url "$DB_URL" --dry-run > reconstruction-dry-run.txt 2>&1
cat reconstruction-migration-list.txt reconstruction-dry-run.txt
python3 - <<'PY'
import json
from pathlib import Path
expected = json.loads(Path('supabase/reconciliation/production_history.json').read_text())
actual = json.loads(Path('reconstructed-catalog.json').read_text())['history']
files = sorted(Path('supabase/migrations').glob('*.sql'))
assert sorted(actual, key=lambda r: r['version']) == expected
assert [p.stem for p in files] == [r['version']+'_'+r['name'] for r in expected]
text = Path('reconstruction-dry-run.txt').read_text()
assert not any(p.name in text for p in files), text
assert 'up to date' in text.lower(), text
print('Zero historical pending: PASS (25 authoritative versions, CLI dry-run).')
PY
# The full current-lineage Auth/RLS/Storage behavioral suite runs independently
# in clean-schema. Here preserve exact historical equivalence, then apply and
# verify only current main's NEW, unapplied hardening on top of that baseline.
psql "$DB_URL" -X -v ON_ERROR_STOP=1 \
  -f "$backup/20261003235000_ai_base_url_ssrf_hardening.sql"
psql "$DB_URL" -X -v ON_ERROR_STOP=1 -f supabase/reconciliation/security_regression.sql
