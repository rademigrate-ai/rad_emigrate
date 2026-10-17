"""Static integrity gates complement the executed SQL / JWT regressions."""
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[2]
FILES={
 '20261010010000_stage1_p0_security_completion.sql':'76a28a9aa6294f6a8ca8f108394b801a2ee85f85827104246324f69787610bd5',
 '20261010055013_stage1_atomic_ai_quota_reservation.sql':'51ab2b39fb63655fea7e67e1a7aef69bb1ba15297877bc39168b90b2b1c8b646',
 '20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql':'b94878391d4fddb9887e74d9a2a1dc809360de46f989a3d599a5471cc7c42fc5',
 '20261012110945_stage1_security_abuse_storage_alignment.sql':'9de2fdb764aae7068c9355b07cd3593823bd66b5da73448687693fe5cc535119',
 '20261012230000_ai_models_check_constraints_alignment.sql':'d4563930461176e6481df29cf587c9dca0eb7b4987395c05af2f613758452fbc',
}

class PhaseASecurity(unittest.TestCase):
    def test_source_blob_integrity(self):
        for name,expected in FILES.items():
            self.assertEqual(hashlib.sha256((ROOT/'supabase/migrations'/name).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),expected,name)

    def test_complete_unique_ordered_chain(self):
        names=sorted(p.name for p in (ROOT/'supabase/migrations').glob('*.sql'))
        # Preserve the exact 46-migration historical base and the five pinned
        # Stage 1 additions while allowing later reviewed forward migrations.
        self.assertGreaterEqual(len(names),51)
        self.assertEqual(len({n[:14] for n in names}),len(names))
        self.assertEqual(names[46:51],list(FILES))
        self.assertTrue(all(n[:14] > '20261012230000' for n in names[51:]))

    def test_reconstruction_does_not_omit_security_files(self):
        script=(ROOT/'scripts/verify_migration_reconstruction.sh').read_text()
        for name in FILES:
            self.assertEqual(script.count(name),3 if name.startswith('20261012230000') else 2,name)
        self.assertIn('phase_a_security.sql',script)

    def test_full_core_fingerprint_guard_preserved(self):
        script=(ROOT/'scripts/verify_clean_schema.sh').read_text()
        fp=json.loads(re.search(r"expected_fingerprint='([^']+)'",script)[1])
        self.assertEqual(set(fp),{'columns','constraints','indexes','functions','triggers','policies','rls','bucket'})
        self.assertEqual(fp['policies'],'5b8620228bf8c9346092eb66f1afa4cb')
        self.assertIn('phase_a_security.sql',script)
        self.assertIn('refuse non-loopback',script)

    def test_no_destructive_or_operational_sql(self):
        for name in FILES:
            sql=(ROOT/'supabase/migrations'/name).read_text()
            statements=re.sub(r'--[^\n]*','',sql).lower()
            for pattern in [r'\btruncate\b',r'\bdrop\s+(table|schema|database)\b',r'\bdisable\s+row\s+level\s+security\b',r'\bdelete\s+from\b',r'\balter\s+default\s+privileges\b']:
                self.assertNotRegex(statements,pattern,name)

    def test_disposable_behavioral_checks_rollback(self):
        sql=(ROOT/'supabase/tests/phase_a_security.sql').read_text().lower()
        self.assertTrue(sql.rstrip().endswith('rollback;'))
        for required in ['cross-owner quota','direct consultation insert','fourth hourly','eleventh daily','negative latency','both active human feed guards']:
            self.assertIn(required,sql)

    def test_missing_check_backfill_uses_exact_migration(self):
        sql=(ROOT/'supabase/tests/phase_a_constraint_backfill.sql').read_text()
        self.assertIn('\\set phase_a_migration ../migrations/20261012230000_ai_models_check_constraints_alignment.sql',sql)
        self.assertIn('\\ir :phase_a_migration',sql)
        self.assertIn('Backfilled CHECK definition differs',sql)
        self.assertIn('Backfill changed rows or migration history',sql)
        for name in ('verify_clean_schema.sh','verify_migration_reconstruction.sh'):
            self.assertIn('phase_a_constraint_backfill.sql',(ROOT/'scripts'/name).read_text())

if __name__=='__main__':unittest.main()
